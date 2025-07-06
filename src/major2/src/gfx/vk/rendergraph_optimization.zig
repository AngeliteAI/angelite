const std = @import("std");
const vk = @import("vulkan");
const rendergraph = @import("rendergraph.zig");

// Enhanced task batching with dependency analysis
pub fn createOptimizedTaskBatches(self: *rendergraph.RenderGraph) !void {
    // Build dependency graph
    const dep_graph = try buildDependencyGraph(self.allocator, self.tasks.items);
    defer dep_graph.deinit();
    
    // Find tasks that can run in parallel
    const parallel_groups = try findParallelGroups(self.allocator, &dep_graph);
    defer parallel_groups.deinit();
    
    // Create batches from parallel groups
    for (parallel_groups.items) |group| {
        var batch = rendergraph.TaskBatch.init(self.allocator, 0);
        
        for (group.tasks.items) |task_idx| {
            try batch.tasks.append(task_idx);
        }
        
        // Only insert barriers if needed between this batch and the next
        if (group.needs_barrier_after) {
            try self.insertMinimalBarriers(&batch, group.resource_transitions);
        }
        
        try self.task_batches.append(batch);
    }
    
    // Apply split barrier optimization if enabled
    if (self.use_split_barriers) {
        try self.optimizeSplitBarriers();
    }
}

const DependencyGraph = struct {
    allocator: std.mem.Allocator,
    nodes: std.ArrayList(Node),
    
    const Node = struct {
        task_idx: usize,
        reads: std.ArrayList(ResourceAccess),
        writes: std.ArrayList(ResourceAccess),
        dependencies: std.ArrayList(usize), // Tasks that must run before this one
        dependents: std.ArrayList(usize), // Tasks that depend on this one
    };
    
    const ResourceAccess = struct {
        resource_id: rendergraph.ResourceId,
        stage: rendergraph.PipelineStage,
        access: rendergraph.AccessType,
        
        fn conflicts(self: ResourceAccess, other: ResourceAccess) bool {
            if (self.resource_id.index != other.resource_id.index) return false;
            
            // Write-after-write, write-after-read, or read-after-write conflicts
            if (self.access.write or other.access.write) {
                // Concurrent writes are allowed if both marked concurrent
                if (self.access.write and other.access.write and 
                    self.access.concurrent and other.access.concurrent) {
                    return false;
                }
                return true;
            }
            
            // Read-after-read is always safe
            return false;
        }
    };
    
    fn init(allocator: std.mem.Allocator) DependencyGraph {
        return .{
            .allocator = allocator,
            .nodes = std.ArrayList(Node).init(allocator),
        };
    }
    
    fn deinit(self: *DependencyGraph) void {
        for (self.nodes.items) |*node| {
            node.reads.deinit();
            node.writes.deinit();
            node.dependencies.deinit();
            node.dependents.deinit();
        }
        self.nodes.deinit();
    }
};

fn buildDependencyGraph(allocator: std.mem.Allocator, tasks: []const rendergraph.Task) !DependencyGraph {
    var graph = DependencyGraph.init(allocator);
    
    // Create nodes for each task
    for (tasks, 0..) |task, idx| {
        var node = DependencyGraph.Node{
            .task_idx = idx,
            .reads = std.ArrayList(DependencyGraph.ResourceAccess).init(allocator),
            .writes = std.ArrayList(DependencyGraph.ResourceAccess).init(allocator),
            .dependencies = std.ArrayList(usize).init(allocator),
            .dependents = std.ArrayList(usize).init(allocator),
        };
        
        // Categorize resource accesses
        for (task.attachments) |attachment| {
            const resource_id = switch (attachment.resource) {
                .buffer => |view| view.id,
                .image => |view| view.id,
                .blas => |view| view.id,
                .tlas => |view| view.id,
            };
            
            const access = DependencyGraph.ResourceAccess{
                .resource_id = resource_id,
                .stage = attachment.stage,
                .access = attachment.access,
            };
            
            if (attachment.access.write) {
                try node.writes.append(access);
            } else {
                try node.reads.append(access);
            }
        }
        
        try graph.nodes.append(node);
    }
    
    // Build dependencies
    for (graph.nodes.items, 0..) |*node_a, idx_a| {
        for (graph.nodes.items[idx_a + 1..], idx_a + 1..) |*node_b, idx_b_rel| {
            const idx_b = idx_a + 1 + idx_b_rel;
            
            // Check if node_b depends on node_a
            var depends = false;
            
            // Check write-after-write and write-after-read
            for (node_a.writes.items) |write_a| {
                for (node_b.writes.items) |write_b| {
                    if (write_a.conflicts(write_b)) {
                        depends = true;
                        break;
                    }
                }
                if (depends) break;
                
                for (node_b.reads.items) |read_b| {
                    if (write_a.conflicts(read_b)) {
                        depends = true;
                        break;
                    }
                }
                if (depends) break;
            }
            
            // Check read-after-write
            if (!depends) {
                for (node_a.reads.items) |read_a| {
                    for (node_b.writes.items) |write_b| {
                        if (read_a.conflicts(write_b)) {
                            depends = true;
                            break;
                        }
                    }
                    if (depends) break;
                }
            }
            
            if (depends) {
                try node_b.dependencies.append(idx_a);
                try node_a.dependents.append(idx_b);
            }
        }
    }
    
    return graph;
}

const ParallelGroup = struct {
    tasks: std.ArrayList(usize),
    needs_barrier_after: bool,
    resource_transitions: std.ArrayList(ResourceTransition),
    
    const ResourceTransition = struct {
        resource_id: rendergraph.ResourceId,
        src_stage: vk.PipelineStageFlags2,
        dst_stage: vk.PipelineStageFlags2,
        src_access: vk.AccessFlags2,
        dst_access: vk.AccessFlags2,
        old_layout: ?vk.ImageLayout,
        new_layout: ?vk.ImageLayout,
    };
};

fn findParallelGroups(allocator: std.mem.Allocator, graph: *const DependencyGraph) !std.ArrayList(ParallelGroup) {
    var groups = std.ArrayList(ParallelGroup).init(allocator);
    var processed = try allocator.alloc(bool, graph.nodes.items.len);
    defer allocator.free(processed);
    @memset(processed, false);
    
    // Topological sort with level assignment
    var levels = try assignLevels(allocator, graph);
    defer levels.deinit();
    
    // Group tasks by level (all tasks in same level can run in parallel)
    var current_level: u32 = 0;
    while (current_level < levels.items.len) : (current_level += 1) {
        var group = ParallelGroup{
            .tasks = std.ArrayList(usize).init(allocator),
            .needs_barrier_after = current_level + 1 < levels.items.len,
            .resource_transitions = std.ArrayList(ParallelGroup.ResourceTransition).init(allocator),
        };
        
        // Add all tasks at this level
        for (levels.items[current_level].items) |task_idx| {
            try group.tasks.append(task_idx);
            processed[task_idx] = true;
        }
        
        // Determine resource transitions needed after this group
        if (group.needs_barrier_after) {
            try calculateResourceTransitions(graph, &group, levels.items[current_level + 1].items);
        }
        
        try groups.append(group);
    }
    
    return groups;
}

fn assignLevels(allocator: std.mem.Allocator, graph: *const DependencyGraph) !std.ArrayList(std.ArrayList(usize)) {
    var levels = std.ArrayList(std.ArrayList(usize)).init(allocator);
    var task_levels = try allocator.alloc(u32, graph.nodes.items.len);
    defer allocator.free(task_levels);
    @memset(task_levels, 0);
    
    // Calculate level for each task (longest path from root)
    var changed = true;
    while (changed) {
        changed = false;
        for (graph.nodes.items, 0..) |node, idx| {
            for (node.dependencies.items) |dep_idx| {
                const new_level = task_levels[dep_idx] + 1;
                if (new_level > task_levels[idx]) {
                    task_levels[idx] = new_level;
                    changed = true;
                }
            }
        }
    }
    
    // Group tasks by level
    const max_level = std.mem.max(u32, task_levels);
    var level_idx: u32 = 0;
    while (level_idx <= max_level) : (level_idx += 1) {
        var level_tasks = std.ArrayList(usize).init(allocator);
        for (task_levels, 0..) |level, idx| {
            if (level == level_idx) {
                try level_tasks.append(idx);
            }
        }
        if (level_tasks.items.len > 0) {
            try levels.append(level_tasks);
        }
    }
    
    return levels;
}

fn calculateResourceTransitions(
    graph: *const DependencyGraph,
    current_group: *ParallelGroup,
    next_tasks: []const usize,
) !void {
    // Track resource states after current group
    var resource_states = std.AutoHashMap(rendergraph.ResourceId, ResourceState).init(current_group.tasks.allocator);
    defer resource_states.deinit();
    
    const ResourceState = struct {
        stage: vk.PipelineStageFlags2,
        access: vk.AccessFlags2,
        layout: ?vk.ImageLayout,
    };
    
    // Collect final states from current group
    for (current_group.tasks.items) |task_idx| {
        const node = &graph.nodes.items[task_idx];
        
        for (node.writes.items) |write| {
            try resource_states.put(write.resource_id, .{
                .stage = pipelineStageToVk(write.stage),
                .access = accessTypeToVk(write.access),
                .layout = null, // TODO: Track image layouts
            });
        }
        
        for (node.reads.items) |read| {
            if (!resource_states.contains(read.resource_id)) {
                try resource_states.put(read.resource_id, .{
                    .stage = pipelineStageToVk(read.stage),
                    .access = accessTypeToVk(read.access),
                    .layout = null,
                });
            }
        }
    }
    
    // Find required transitions for next tasks
    for (next_tasks) |task_idx| {
        const node = &graph.nodes.items[task_idx];
        
        for (node.reads.items) |read| {
            if (resource_states.get(read.resource_id)) |current_state| {
                const new_stage = pipelineStageToVk(read.stage);
                const new_access = accessTypeToVk(read.access);
                
                if (current_state.stage != new_stage or current_state.access != new_access) {
                    try current_group.resource_transitions.append(.{
                        .resource_id = read.resource_id,
                        .src_stage = current_state.stage,
                        .dst_stage = new_stage,
                        .src_access = current_state.access,
                        .dst_access = new_access,
                        .old_layout = current_state.layout,
                        .new_layout = null,
                    });
                }
            }
        }
        
        for (node.writes.items) |write| {
            if (resource_states.get(write.resource_id)) |current_state| {
                const new_stage = pipelineStageToVk(write.stage);
                const new_access = accessTypeToVk(write.access);
                
                if (current_state.stage != new_stage or current_state.access != new_access) {
                    try current_group.resource_transitions.append(.{
                        .resource_id = write.resource_id,
                        .src_stage = current_state.stage,
                        .dst_stage = new_stage,
                        .src_access = current_state.access,
                        .dst_access = new_access,
                        .old_layout = current_state.layout,
                        .new_layout = null,
                    });
                }
            }
        }
    }
}

// Split barrier optimization
fn optimizeSplitBarriers(self: *rendergraph.RenderGraph) !void {
    if (self.task_batches.items.len < 2) return;
    
    var split_barrier_system = SplitBarrierSystem.init(self.allocator);
    defer split_barrier_system.deinit();
    
    // Analyze barriers between consecutive batches
    var batch_idx: usize = 0;
    while (batch_idx + 1 < self.task_batches.items.len) : (batch_idx += 1) {
        const current_batch = &self.task_batches.items[batch_idx];
        const next_batch = &self.task_batches.items[batch_idx + 1];
        
        // Find barriers that can be split
        for (current_batch.barriers.items, 0..) |*barrier, barrier_idx| {
            if (canSplitBarrier(barrier, current_batch, next_batch)) {
                // Convert to split barrier
                const event = try split_barrier_system.allocateEvent();
                
                const split_barrier = rendergraph.SplitBarrier{
                    .barrier = barrier.*,
                    .event = event,
                    .signal_batch = batch_idx,
                    .wait_batch = batch_idx + 1,
                };
                
                try current_batch.split_barriers.append(split_barrier);
                
                // Remove original barrier
                _ = current_batch.barriers.orderedRemove(barrier_idx);
            }
        }
    }
}

fn canSplitBarrier(
    barrier: *const rendergraph.Barrier,
    current_batch: *const rendergraph.TaskBatch,
    next_batch: *const rendergraph.TaskBatch,
) bool {
    // Split barriers are beneficial when:
    // 1. The barrier is between different pipeline stages
    // 2. There's significant work in both batches
    // 3. The barrier doesn't involve layout transitions (those need immediate execution)
    
    if (barrier.image != null and barrier.image.?.old_layout != barrier.image.?.new_layout) {
        return false; // Layout transitions can't be split
    }
    
    // Check if stages are different enough to benefit
    const stage_mask = barrier.src_stage | barrier.dst_stage;
    const is_compute_to_graphics = (barrier.src_stage & vk.PipelineStageFlags2{ .compute_shader_bit = true }) != 0 and
                                  (barrier.dst_stage & vk.PipelineStageFlags2{ .vertex_shader_bit = true }) != 0;
    const is_graphics_to_compute = (barrier.src_stage & vk.PipelineStageFlags2{ .fragment_shader_bit = true }) != 0 and
                                  (barrier.dst_stage & vk.PipelineStageFlags2{ .compute_shader_bit = true }) != 0;
    
    if (!is_compute_to_graphics and !is_graphics_to_compute) {
        return false; // Not worth splitting
    }
    
    // Check batch sizes
    if (current_batch.tasks.items.len < 5 or next_batch.tasks.items.len < 5) {
        return false; // Not enough work to hide the barrier
    }
    
    return true;
}

const SplitBarrierSystem = struct {
    allocator: std.mem.Allocator,
    event_pool: std.ArrayList(vk.Event),
    next_event_idx: usize,
    
    fn init(allocator: std.mem.Allocator) SplitBarrierSystem {
        return .{
            .allocator = allocator,
            .event_pool = std.ArrayList(vk.Event).init(allocator),
            .next_event_idx = 0,
        };
    }
    
    fn deinit(self: *SplitBarrierSystem) void {
        self.event_pool.deinit();
    }
    
    fn allocateEvent(self: *SplitBarrierSystem) !vk.Event {
        // In real implementation, this would get events from a pool
        // For now, return a placeholder
        self.next_event_idx += 1;
        return @intToEnum(vk.Event, self.next_event_idx);
    }
};

fn pipelineStageToVk(stage: rendergraph.PipelineStage) vk.PipelineStageFlags2 {
    return switch (stage) {
        .none => .{},
        .vertex_shader => .{ .vertex_shader_bit = true },
        .fragment_shader => .{ .fragment_shader_bit = true },
        .compute_shader => .{ .compute_shader_bit = true },
        .transfer => .{ .transfer_bit = true },
        .color_attachment => .{ .color_attachment_output_bit = true },
        .depth_stencil_attachment => .{ .early_fragment_tests_bit = true, .late_fragment_tests_bit = true },
        .ray_tracing_shader => .{ .ray_tracing_shader_bit_khr = true },
        .acceleration_structure_build => .{ .acceleration_structure_build_bit_khr = true },
        .host => .{ .host_bit = true },
        else => .{ .all_commands_bit = true },
    };
}

fn accessTypeToVk(access: rendergraph.AccessType) vk.AccessFlags2 {
    var flags = vk.AccessFlags2{};
    if (access.read) flags.shader_read_bit = true;
    if (access.write) flags.shader_write_bit = true;
    if (access.sampled) flags.shader_sampled_read_bit = true;
    return flags;
}

// Public API extension
pub fn insertMinimalBarriers(
    self: *rendergraph.RenderGraph,
    batch: *rendergraph.TaskBatch,
    transitions: []const ParallelGroup.ResourceTransition,
) !void {
    // Group transitions by resource to minimize barriers
    var barrier_map = std.AutoHashMap(rendergraph.ResourceId, rendergraph.Barrier).init(self.allocator);
    defer barrier_map.deinit();
    
    for (transitions) |transition| {
        const resource = switch (transition.resource_id.index < self.buffers.items.len) {
            true => self.buffers.items[transition.resource_id.index],
            false => continue, // Handle images separately
        };
        
        if (barrier_map.get(transition.resource_id)) |*existing| {
            // Merge with existing barrier
            existing.src_stage = existing.src_stage | transition.src_stage;
            existing.dst_stage = existing.dst_stage | transition.dst_stage;
            existing.src_access = existing.src_access | transition.src_access;
            existing.dst_access = existing.dst_access | transition.dst_access;
        } else {
            // Create new barrier
            try barrier_map.put(transition.resource_id, .{
                .src_stage = transition.src_stage,
                .dst_stage = transition.dst_stage,
                .src_access = transition.src_access,
                .dst_access = transition.dst_access,
                .buffer = .{
                    .handle = resource.handle,
                    .offset = 0,
                    .size = vk.WHOLE_SIZE,
                },
            });
        }
    }
    
    // Add all barriers to batch
    var iter = barrier_map.iterator();
    while (iter.next()) |entry| {
        try batch.barriers.append(entry.value_ptr.*);
    }
}