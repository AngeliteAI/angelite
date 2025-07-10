use super::Node;
use bimap::BiMap;
use crate::{error::*, rng::{Rng, Time}, serde::*, Decode, Encode};
use crate::serde::compact::{Encodable, Op, Code};
use std::{
    collections::{HashMap, HashSet, VecDeque},
    fmt,
    hash::{DefaultHasher, Hash, Hasher, SipHasher},
    marker::PhantomData,
    net::IpAddr,
    ops,
    sync::{Arc, RwLock},
    time::*,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct Request(pub u128);
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct Client(pub u128);
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct Snapshot(pub u128);

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct Log {
    pub term: u64,
    pub index: u64,
}


#[derive(Clone)]
pub enum ReplReq<C> {
    Append {
        leader: Node,
        prev: Log,
        entries: Vec<Entry<C>>,
        commit: u64,
    },
    Commit {
        leader: Node,
        index: u64,
    },
}

#[derive(Clone)]
pub struct SnapReq<C> {
    pub leader: Node,
    pub id: Snapshot,
    pub last: Log,
    pub chunk: Chunk<C>,
}

#[derive(Clone)]
pub struct Chunk<C> {
    pub index: u64,
    pub total: u64,
    pub data: C,
    pub checksum: u64,
}

#[derive(Clone)]
pub enum HealthReq {
    Ping,
    Check,
    Sync,
}

#[derive(Clone)]
pub enum MgmtReq {
    Join {
        node: Node,
        addr: IpAddr,
        peers: HashSet<Node>,
    },
    Add {
        node: Node,
        addr: IpAddr,
    },
    Remove {
        node: Node,
    },
    Discover,
    Config(Config),
}

#[derive(Clone)]
pub struct ClientReq<C> {
    pub id: Request,
    pub client: Client,
    pub cmd: C,
}

// ===== RESPONSES =====

pub enum Resp<R> {
    Vote(VoteResp),
    Lead(LeadResp),
    Repl(ReplResp),
    Snap(SnapResp),
    Health(HealthResp),
    Mgmt(MgmtResp),
    Client(ClientResp<R>),
}

pub enum VoteResp {
    Grant {
        voter: Node,
        term: u64,
    },
    Deny {
        voter: Node,
        term: u64,
        reason: DenyVote,
    },
}

pub enum LeadResp {
    Elected { leader: Node, term: u64 },
    Stepped { node: Node, term: u64 },
    Ack { follower: Node, epoch: u64 },
}

pub enum ReplResp {
    Accept { follower: Node, match_idx: u64 },
    Reject { follower: Node, reason: RejectRepl },
    Applied { index: u64 },
}

pub enum SnapResp {
    Ack { follower: Node, chunk: u64 },
    Reject { follower: Node, reason: RejectSnap },
    Done { follower: Node, last: u64 },
}

pub enum HealthResp {
    Pong { node: Node, ts: u64 },
    Status { node: Node, metrics: Metrics },
    Synced { node: Node, at: u64 },
}

pub enum MgmtResp {
    Joined { node: Node, cluster: HashSet<Node> },
    Added { node: Node },
    Removed { node: Node },
    Peers { peers: HashSet<Node> },
    Updated,
}

#[derive(Clone)]
pub enum ClientResp<R> {
    Ok { id: Request, result: R },
    Err { id: Request, reason: ClientErr },
}

// ===== REASONS =====

pub enum DenyVote {
    Term { voter: u64 },
    Voted { for_node: Node },
    Log { at: u64, term: u64 },
    Unready,
}

#[derive(Clone)]
pub enum StepReason {
    Term { found: u64 },
    Quorum,
    Partition,
    Admin,
    Health,
}

pub struct RejectRepl {
    pub expect_idx: u64,
    pub expect_term: u64,
    pub have_len: u64,
    pub conflict: Option<(u64, u64)>,
}

pub enum RejectSnap {
    Checksum,
    Order,
    Version,
    Space,
}

#[derive(Clone)]
pub enum ClientErr {
    NotLeader { hint: Option<Node> },
    Timeout,
    Invalid,
}

// ===== SUPPORT =====

#[derive(Clone)]
pub enum Config {
    Bootstrap { port: u16 },
    Join { known_addr: IpAddr },
    Known { nodes: HashSet<Node> },
}

pub struct Settings {
    port: u16,
    public: Option<IpAddr>,
    magic: Option<IpAddr>,
    known: BiMap<Node, Option<IpAddr>>,
    heartbeat: Duration,
}

pub struct Metrics {
    pub cpu: f32,
    pub mem: u64,
    pub disk: u64,
    pub net: u64,
    pub up_ms: u64,
    pub fail_rate: f32,
}

pub type Bytes = usize;
pub struct Header {
    pub len: Bytes,
    pub sender: Node,
    pub recipient: Node,
}
pub struct Packet<T> {
    pub header: Header,
    pub inner: Vec<T>,
}

impl<T> ops::Deref for Packet<T> {
    type Target = [T];
    fn deref(&self) -> &Self::Target {
        &*self.inner
    }
}

impl<T> ops::DerefMut for Packet<T> {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut *self.inner
    }
}

// ===== ERRORS =====

pub struct Raft<Req: super::State<Sub, Output = Cmd, Error = Failure>, Cmd, Sub> {
    inner: Arc<Req>,
    applied: Vec<Entry<Cmd>>,
    last: u64,
    term: u64,
    snapshot_last: Option<Log>,
    pending_apply: Vec<Entry<Cmd>>,
    client_sessions: HashMap<Client, Request>,
    election_timer: Instant,
    randomized_timeout: Duration,
    snapshot_in_progress: Option<SnapshotProgress>,
    subcmd: PhantomData<Sub>,
}
struct SnapshotProgress {
    id: Snapshot,
    chunks: HashMap<u64, Vec<u8>>,
    total_chunks: u64,
    last_included: Log,
    checksum: u64,
    started_at: Instant,
}

struct SnapshotStore {
    snapshots: HashMap<Snapshot, CompleteSnapshot>,
    pending: HashMap<Snapshot, SnapshotBuilder>,
}

struct CompleteSnapshot {
    data: Vec<u8>,
    last_included: Log,
    checksum: u64,
    created_at: Instant,
}

struct SnapshotBuilder {
    chunks: HashMap<u64, Vec<u8>>,
    total_chunks: u64,
    expected_checksum: u64,
    last_included: Log,
}
impl<Cmd, Req: super::State<T, Output = Cmd, Error = Failure>, T> super::State<Cmd>
    for Raft<Req, Cmd, T>
where
    Req: super::State<Cmd, Output = Vec<Packet<Cmd>>, Error = Failure>,
{
    type Output = Vec<Packet<Cmd>>;
    type Error = Failure;

    fn process(&self, commands: &[(Node, Cmd)]) -> Result<Self::Output, Self::Error> {
        // Process commands through the requester
        self.inner.process(commands)
    }

    fn tick(&self) -> Result<Vec<(Node, Cmd)>, <Req as super::State<Cmd>>::Error> {
        <Req as super::State<Cmd>>::tick(self.inner.as_ref())
    }
}

#[derive(Debug)]
pub struct VolatileState {
    pub id: Node,
    pub commit_index: u64,
    pub last_applied: u64,
    pub last_known_leader: Option<Node>,
}

#[derive(Debug)]
pub struct ReadRequest {
    pub client_id: Client,
    pub request_index: u64,
    pub received_at: Instant,
    pub context: Vec<u8>,
}

#[derive(Debug)]
pub struct PreVoteState {
    pub candidate: Node,
    pub candidate_term: u64,
    pub candidate_last: Log,
    pub granted: HashSet<Node>,
    pub denied: HashSet<Node>,
    pub started_at: Instant,
    pub cluster_size: usize,
    pub already_voted: bool,
}

pub struct PersistentState<Cmd: Encode> {
    pub log: Vec<Entry<Cmd>>, // Encoded commands
    pub snapshot_last: Log,

    pub current_term: u64,
    pub voted_for: Option<Node>,
    pub snapshot: Option<Snapshot>,

    pub settings: Settings,
}

pub struct Processor<Cmd, S, R>
where
    Cmd: Encode + Decode,
    S: super::State<Cmd, Output = R, Error = Failure>,
{
    pub state: Arc<RwLock<State<Cmd>>>,
    pub machine: S,
}

pub struct State<Cmd: Encode> {
    pub persistent: PersistentState<Cmd>,

    pub role: Role<Cmd>,

    pub volatile: VolatileState,

    pub config: Config,

    pub cluster: HashSet<Node>,

    pub snapshot_store: Arc<RwLock<SnapshotStore>>,
}

pub enum Role<Cmd> {
    Follower(FollowerState),
    Candidate(CandidateState),
    Leader(LeaderState<Cmd>),
    Learner(LearnerState), // Non-voting member
}

impl Default for FollowerState {
    fn default() -> Self {
        FollowerState {
            leader_id: None,
            voted_for: None,
            last_heartbeat: Instant::now(),
            election_timeout: Duration::from_secs(5),
            lease_holder: None,
        }
    }
}

#[derive(Clone, Debug)]
pub struct FollowerState {
    pub leader_id: Option<Node>,
    pub voted_for: Option<Node>,
    pub last_heartbeat: Instant,
    pub election_timeout: Duration,
    pub lease_holder: Option<LeaseInfo>,
}

pub struct InFlightAppend<Cmd> {
    pub follower: Node,
    pub term: u64,
    pub prev_log: Log,
    pub entries: Vec<Entry<Cmd>>,
    pub leader_commit: u64,
    pub sent_at: Instant,
    pub retry_count: u32,
    pub expected_next_index: u64,
}

impl<Cmd> fmt::Debug for InFlightAppend<Cmd> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("InFlightAppend")
            .field("follower", &self.follower)
            .field("term", &self.term)
            .field("prev_log", &self.prev_log)
            .field("leader_commit", &self.leader_commit)
            .field("sent_at", &self.sent_at)
            .field("retry_count", &self.retry_count)
            .field("expected_next_index", &self.expected_next_index)
            .finish()
    }
}

pub struct CandidateState {
    pub votes_received: HashMap<Node, VoteResp>,
    pub election_started: Instant,
    pub election_timeout: Duration,
    pub pre_vote_state: Option<PreVoteState>,
    pub election_round: u32, // For exponential backoff
}

impl<Cmd> Default for LeaderState<Cmd> {
    fn default() -> Self {
        LeaderState {
            next_index: HashMap::new(),
            match_index: HashMap::new(),
            in_flight_appends: HashMap::new(),
            replication_state: HashMap::new(),
            lease_epoch: 0,
            last_heartbeat_sent: HashMap::new(),
            batch_buffer: BatchBuffer::default(),
            read_index_state: ReadIndexState::default(),
        }
    }
}

#[derive(Debug)]
pub struct LeaderState<Cmd> {
    pub next_index: HashMap<Node, u64>,
    pub match_index: HashMap<Node, u64>,
    pub in_flight_appends: HashMap<Node, VecDeque<InFlightAppend<Cmd>>>,
    pub replication_state: HashMap<Node, ReplicationState>,
    pub lease_epoch: u64,
    pub last_heartbeat_sent: HashMap<Node, Instant>,
    pub batch_buffer: BatchBuffer,
    pub read_index_state: ReadIndexState,
}

#[derive(Clone, Debug)]
pub struct LeaseInfo {
    pub leader_id: Node,
    pub epoch: u64,
    pub expires_at: Instant,
}

#[derive(Clone, Debug)]
pub struct ReplicationState {
    pub consecutive_successes: u32,
    pub consecutive_failures: u32,
    pub last_success: Option<Instant>,
    pub last_failure: Option<Instant>,
    pub average_latency: Duration,
    pub pipeline_depth: usize,
}

#[derive(Clone, Debug, Default)]
pub struct BatchBuffer {
    pub entries: Vec<PendingEntry>,
    pub size_bytes: usize,
    pub oldest_entry: Option<Instant>,
}

#[derive(Clone, Debug)]
pub struct PendingEntry {
    pub command: Vec<u8>, // Encoded command
    pub client_id: Client,
    pub request_id: Request,
    pub received_at: Instant,
}

#[derive(Debug, Default)]
pub struct ReadIndexState {
    pub pending_reads: HashMap<Request, ReadRequest>,
    pub confirmed_index: u64,
    pub confirming_nodes: HashSet<Node>,
}

#[derive(Clone, Debug)]
pub struct LearnerState {
    pub leader_id: Option<Node>,
    pub sync_progress: f32,
    pub catching_up_from: u64,
    pub promotion_eligible: bool,
}

enum TickAction {
    StartElection,
    RestartElection { new_timeout: Duration, round: u32 },
    SendHeartbeat { to: Node },
    FlushBatch,
    RetryAppend { to: Node },
    MarkFollowerStale { node: Node },
    ExpireRead { request_id: Request },
    RequestSnapshot,
    CleanupSnapshot { id: Snapshot },
}

pub struct FineGrained<Cmd: Encodee> {
    pub inner: Arc<dyn super::State<Cmd, Output = Vec<(Node, Cmd)>, Error = Failure>>,
    pub state: Arc<RwLock<State<Cmd>>>,
    pub rng: Arc<dyn Rng>,
}

impl<Cmd: Clone + Encode + Decode> FineGrained<Cmd> {
    pub fn new(
        inner: Arc<dyn super::State<Cmd, Output = Vec<(Node, Cmd)>, Error = Failure>>,
        state: Arc<RwLock<State<Cmd>>>,
        rng: Arc<dyn Rng>,
    ) -> Self {
        Self {
            inner,
            state,
            rng,
        }
    }

    pub fn handle_vote_request(
        &self,
        req: &VoteReq,
        state: &mut State<Cmd>,
    ) -> Result<VoteResp, Failure> {
        match req {
            VoteReq::Ask { candidate, last } | VoteReq::Pre { candidate, last } => {
                // Term check
                let term_ok = state.persistent.current_term <= last.term;
                let grant_vote = {
                    // Log freshness check
                    let log_ok = if let Some(last_entry) = state.persistent.log.last() {
                        last.term > last_entry.term
                            || (last.term == last_entry.term && last.index >= last_entry.index)
                    } else {
                        true
                    };

                    // Vote check - haven't voted for anyone else
                    let vote_ok = state.persistent.voted_for.is_none()
                        || state.persistent.voted_for == Some(*candidate);

                    term_ok && log_ok && vote_ok
                };

                Ok(if grant_vote {
                    if matches!(req, VoteReq::Ask { .. }) {
                        state.persistent.voted_for = Some(*candidate);
                    }
                    VoteResp::Grant {
                        voter: state.volatile.id,
                        term: state.persistent.current_term,
                    }
                } else {
                    VoteResp::Deny {
                        voter: state.volatile.id,
                        term: state.persistent.current_term,
                        reason: if !term_ok {
                            DenyVote::Term {
                                voter: state.persistent.current_term,
                            }
                        } else if let Some(voted_for) = state.persistent.voted_for {
                            DenyVote::Voted {
                                for_node: voted_for,
                            }
                        } else {
                            DenyVote::Log {
                                at: state.persistent.log.len() as u64,
                                term: state.persistent.log.last().map(|e| e.term).unwrap_or(0),
                            }
                        },
                    }
                })
            }
        }
    }

    pub fn handle_lead_request(
        &self,
        req: &LeadReq,
        state: &mut State<Cmd>,
    ) -> Result<LeadResp, Failure> {
        match req {
            LeadReq::Elect { node, votes } => {
                // Verify election and transition to leader if valid
                let required_votes = (state.cluster.len() / 2) + 1;
                Ok(
                    if votes.len() >= required_votes && *node == state.volatile.id {
                        // Become leader
                        let mut next_index = HashMap::new();
                        let mut match_index = HashMap::new();
                        let last_log_index = state.persistent.log.len() as u64;

                        for peer in &state.cluster {
                            if *peer != state.volatile.id {
                                next_index.insert(*peer, last_log_index + 1);
                                match_index.insert(*peer, 0);
                            }
                        }

                        state.role = Role::Leader(LeaderState::default());

                        state.volatile.last_known_leader = Some(state.volatile.id);

                        LeadResp::Elected {
                            leader: state.volatile.id,
                            term: state.persistent.current_term,
                        }
                    } else {
                        LeadResp::Stepped {
                            node: state.volatile.id,
                            term: state.persistent.current_term,
                        }
                    },
                )
            }
            LeadReq::Step { node, reason } => {
                // Step down from leadership
                if matches!(state.role, Role::Leader(_)) {
                    state.role = Role::Follower(FollowerState::default());
                }
                Ok(LeadResp::Stepped {
                    node: state.volatile.id,
                    term: state.persistent.current_term,
                })
            }
            LeadReq::Pulse {
                leader,
                epoch,
                commit,
            } => {
                // Handle heartbeat
                if let Role::Follower(ref mut follower_state) = state.role {
                    follower_state.last_heartbeat = Instant::now();
                    follower_state.leader_id = Some(*leader);
                    state.volatile.last_known_leader = Some(*leader);

                    // Update commit index if needed
                    if *commit > state.volatile.commit_index {
                        state.volatile.commit_index =
                            (*commit).min(state.persistent.log.len() as u64);
                    }
                }
                Ok(LeadResp::Ack {
                    follower: state.volatile.id,
                    epoch: *epoch,
                })
            }
        }
    }

    fn handle_repl_request(&self, req: &ReplReq<Cmd>, state: &mut State<Cmd>) -> ReplResp {
        match req {
            ReplReq::Append {
                leader,
                prev,
                entries,
                commit,
            } => {
                // Check term
                if prev.term > state.persistent.current_term {
                    return ReplResp::Reject {
                        follower: state.volatile.id,
                        reason: RejectRepl {
                            expect_idx: 0,
                            expect_term: state.persistent.current_term,
                            have_len: state.persistent.log.len() as u64,
                            conflict: None,
                        },
                    };
                }

                // Check if we have the previous log entry
                if prev.index > 0 {
                    if let Some(entry) = state.persistent.log.get((prev.index - 1) as usize) {
                        if entry.term != prev.term {
                            // Log doesn't match
                            return ReplResp::Reject {
                                follower: state.volatile.id,
                                reason: RejectRepl {
                                    expect_idx: prev.index,
                                    expect_term: prev.term,
                                    have_len: state.persistent.log.len() as u64,
                                    conflict: Some((prev.index, entry.term)),
                                },
                            };
                        }
                    } else {
                        // Don't have the previous entry
                        return ReplResp::Reject {
                            follower: state.volatile.id,
                            reason: RejectRepl {
                                expect_idx: state.persistent.log.len() as u64 + 1,
                                expect_term: 0,
                                have_len: state.persistent.log.len() as u64,
                                conflict: None,
                            },
                        };
                    }
                }

                // Append entries
                let mut log_index = prev.index;
                for entry in entries {
                    if let Some(existing) = state.persistent.log.get(log_index as usize) {
                        if existing.term != entry.term {
                            // Remove conflicting entries
                            state.persistent.log.truncate(log_index as usize);
                        }
                    }

                    if state.persistent.log.len() == log_index as usize {
                        state.persistent.log.push(entry.clone());
                    }
                    log_index += 1;
                }

                // Update commit index
                if *commit > state.volatile.commit_index {
                    state.volatile.commit_index = (*commit).min(state.persistent.log.len() as u64);
                }

                // Update follower state
                if let Role::Follower(ref mut follower_state) = state.role {
                    follower_state.leader_id = Some(*leader);
                    follower_state.last_heartbeat = Instant::now();
                }

                ReplResp::Accept {
                    follower: state.volatile.id,
                    match_idx: state.persistent.log.len() as u64,
                }
            }
            ReplReq::Commit { leader, index } => {
                // Update commit index
                if *index > state.volatile.commit_index
                    && *index <= state.persistent.log.len() as u64
                {
                    state.volatile.commit_index = *index;
                }
                ReplResp::Applied { index: *index }
            }
        }
    }

    fn handle_snap_request(
        &self,
        req: &SnapReq<Cmd>,
        state: &mut State<Cmd>,
    ) -> Result<SnapResp, Failure> {
        let mut snapshot_store = state.snapshot_store.write().unwrap();

        // Get or create snapshot builder
        let builder = snapshot_store
            .pending
            .entry(req.id)
            .or_insert_with(|| SnapshotBuilder {
                chunks: HashMap::new(),
                total_chunks: req.chunk.total,
                expected_checksum: req.chunk.checksum,
                last_included: req.last,
            });

        // Validate chunk
        if req.chunk.index == 0 || req.chunk.index > req.chunk.total {
            return Ok(SnapResp::Reject {
                follower: state.volatile.id,
                reason: RejectSnap::Order,
            });
        }

        // Store chunk
        let chunk_data = req.chunk.data.clone();
        builder.chunks.insert(req.chunk.index, chunk_data);

        // Check if snapshot is complete
        if builder.chunks.len() == builder.total_chunks as usize {
            // Reconstruct snapshot
            let mut complete_data = Vec::new();
            for i in 1..=builder.total_chunks {
                if let Some(chunk) = builder.chunks.get(&i) {
                    complete_data.extend_from_slice(chunk);
                } else {
                    return Ok(SnapResp::Reject {
                        follower: state.volatile.id,
                        reason: RejectSnap::Order,
                    });
                }
            }

            // Verify checksum
            let mut hasher = DefaultHasher::new();
            complete_data.hash(&mut hasher);
            let calculated_checksum = hasher.finish();

            if calculated_checksum != builder.expected_checksum {
                snapshot_store.pending.remove(&req.id);
                return Ok(SnapResp::Reject {
                    follower: state.volatile.id,
                    reason: RejectSnap::Checksum,
                });
            }

            // Apply snapshot
            let snapshot = CompleteSnapshot {
                data: complete_data.clone(),
                last_included: builder.last_included,
                checksum: builder.expected_checksum,
                created_at: Instant::now(),
            };

            // Update state
            state.persistent.snapshot_last = builder.last_included;
            state.persistent.snapshot = Some(req.id);

            // Remove log entries before snapshot
            state.persistent.log.clear();

            // Update commit and applied indices
            state.volatile.commit_index =
                state.volatile.commit_index.max(builder.last_included.index);
            state.volatile.last_applied =
                state.volatile.last_applied.max(builder.last_included.index);

            // Store complete snapshot
            let index_last = builder.last_included.index;
            snapshot_store.snapshots.insert(req.id, snapshot);
            snapshot_store.pending.remove(&req.id);

            // Apply snapshot to state machine
            if let Ok(state_data) = Ser::deserialize(&complete_data) {
                let _ = self.inner.process(&[(state.volatile.id, state_data)]);
            }

            Ok(SnapResp::Done {
                follower: state.volatile.id,
                last: index_last,
            })
        } else {
            Ok(SnapResp::Ack {
                follower: state.volatile.id,
                chunk: req.chunk.index,
            })
        }
    }

    fn handle_health_request(
        &self,
        req: &HealthReq,
        state: &State<Cmd>,
    ) -> Result<HealthResp, Failure> {
        Ok(match req {
            HealthReq::Ping => HealthResp::Pong {
                node: state.volatile.id,
                ts: SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap()
                    .as_secs(),
            },
            HealthReq::Check => HealthResp::Status {
                node: state.volatile.id,
                metrics: self.get_metrics(),
            },
            HealthReq::Sync => {
                let sync_status = match &state.role {
                    Role::Leader(_) => state.volatile.commit_index,
                    _ => state.volatile.last_applied,
                };

                HealthResp::Synced {
                    node: state.volatile.id,
                    at: sync_status,
                }
            }
        })
    }

    fn handle_mgmt_request(
        &self,
        req: &MgmtReq,
        state: &mut State<Cmd>,
    ) -> Result<MgmtResp, Failure> {
        Ok(match req {
            MgmtReq::Join { node, addr, peers } => {
                // Validate join request
                if state.cluster.contains(node) {
                    return Ok(MgmtResp::Peers {
                        peers: state.cluster.clone(),
                    });
                }

                // Update cluster configuration
                state.cluster = peers.clone();
                state.cluster.insert(*node);

                // If we're the leader, replicate configuration change
                if let Role::Leader(leader_state) = &mut state.role {
                    // Add new node to tracking
                    let last_index =
                        state.persistent.snapshot_last.index + state.persistent.log.len() as u64;
                    leader_state.next_index.insert(*node, last_index + 1);
                    leader_state.match_index.insert(*node, 0);
                    leader_state.replication_state.insert(
                        *node,
                        ReplicationState {
                            consecutive_successes: 0,
                            consecutive_failures: 0,
                            last_success: None,
                            last_failure: None,
                            average_latency: Duration::from_millis(0),
                            pipeline_depth: 1,
                        },
                    );
                }

                MgmtResp::Joined {
                    node: *node,
                    cluster: state.cluster.clone(),
                }
            }
            MgmtReq::Add { node, addr } => {
                // Only leader can add nodes
                match &mut state.role {
                    Role::Leader(leader_state) => {
                        if !state.cluster.contains(node) {
                            state.cluster.insert(*node);

                            // Initialize replication state for new node
                            let last_index = state.persistent.snapshot_last.index
                                + state.persistent.log.len() as u64;
                            leader_state.next_index.insert(*node, last_index + 1);
                            leader_state.match_index.insert(*node, 0);
                            leader_state.replication_state.insert(
                                *node,
                                ReplicationState {
                                    consecutive_successes: 0,
                                    consecutive_failures: 0,
                                    last_success: None,
                                    last_failure: None,
                                    average_latency: Duration::from_millis(0),
                                    pipeline_depth: 1,
                                },
                            );
                        }

                        MgmtResp::Added { node: *node }
                    }
                    _ => MgmtResp::Peers {
                        peers: state.cluster.clone(),
                    },
                }
            }
            MgmtReq::Remove { node } => {
                // Only leader can remove nodes
                match &mut state.role {
                    Role::Leader(leader_state) => {
                        state.cluster.remove(node);
                        leader_state.next_index.remove(node);
                        leader_state.match_index.remove(node);
                        leader_state.replication_state.remove(node);
                        leader_state.in_flight_appends.remove(node);

                        MgmtResp::Removed { node: *node }
                    }
                    _ => MgmtResp::Peers {
                        peers: state.cluster.clone(),
                    },
                }
            }
            MgmtReq::Discover => MgmtResp::Peers {
                peers: state.cluster.clone(),
            },
            MgmtReq::Config(new_config) => {
                match new_config {
                    Config::Bootstrap { port } => {
                        state.persistent.settings.port = *port;
                    }
                    Config::Join { known_addr } => {
                        state.persistent.settings.public = Some(*known_addr);
                    }
                    Config::Known { nodes } => {
                        // Update known nodes
                        state.persistent.settings.known = BiMap::new();
                        for node in nodes {
                            if !state.cluster.contains(node) {
                                state.cluster.insert(*node);
                            }
                            if let Some(addr) = state.persistent.settings.known.get_by_left(node) {
                                state.persistent.settings.known.insert(*node, *addr);
                            } else {
                                // Assign a new address if not already known
                                let new_addr = None;

                                state.persistent.settings.known.insert(*node, new_addr);
                            }
                        }
                    }
                }
                MgmtResp::Updated
            }
        })
    }

    /// Apply the actions collected during tick and return any messages to send
    fn apply_tick_actions(
        &self,
        actions: Vec<TickAction>,
    ) -> Result<Vec<(Node, Req<Cmd>)>, Failure> {
        let mut messages = Vec::new();

        for action in actions {
            match action {
                TickAction::StartElection => {
                    messages.extend(self.start_election()?);
                }
                TickAction::RestartElection { new_timeout, round } => {
                    messages.extend(self.restart_election(new_timeout, round)?);
                }
                TickAction::SendHeartbeat { to } => {
                    if let Some(msg) = self.create_heartbeat(to)? {
                        messages.push(msg);
                    }
                }
                TickAction::FlushBatch => {
                    messages.extend(self.flush_batch()?);
                }
                TickAction::RetryAppend { to } => {
                    if let Some(msg) = self.create_retry_append(to)? {
                        messages.push(msg);
                    }
                }
                TickAction::MarkFollowerStale { node } => {
                    self.mark_follower_stale(node)?;
                    // No messages for this action
                }
                TickAction::ExpireRead { request_id } => {
                    // This might generate client response messages
                    if let Some(msg) = self.expire_read_request(request_id)? {
                        messages.push(msg);
                    }
                }
                TickAction::RequestSnapshot => {
                    messages.extend(self.request_snapshot()?);
                }
                TickAction::CleanupSnapshot { id } => {
                    self.cleanup_snapshot(id)?;
                    // No messages for cleanup
                }
            }
        }
        Ok(messages)
    }

    /// Start an election - returns vote request messages
    fn start_election(&self) -> Result<Vec<(Node, Req<Cmd>)>, Failure> {
        let mut state = self
            .state
            .write()
            .map_err(|_| Failure::System(System::Thread))?;

        // Increment term
        state.persistent.current_term += 1;
        state.persistent.voted_for = Some(state.volatile.id);

        // Transition to candidate
        let election_timeout = Duration::from_millis(150 + self.rng.random() as u8 as u64);

        state.role = Role::Candidate(CandidateState {
            votes_received: {
                let mut votes = HashMap::new();
                // Vote for self
                votes.insert(
                    state.volatile.id,
                    VoteResp::Grant {
                        voter: state.volatile.id,
                        term: state.persistent.current_term,
                    },
                );
                votes
            },
            election_started: Instant::now(),
            election_timeout,
            pre_vote_state: None,
            election_round: 1,
        });

        // Prepare vote requests
        let last_log = if let Some(last_entry) = state.persistent.log.last() {
            Log {
                term: last_entry.term,
                index: last_entry.index,
            }
        } else {
            state.persistent.snapshot_last
        };

        let vote_req = Req::Vote(VoteReq::Ask {
            candidate: state.volatile.id,
            last: last_log,
        });

        // Create messages for all peers
        let messages: Vec<(Node, Req<Cmd>)> = state
            .cluster
            .iter()
            .filter(|&&n| n != state.volatile.id)
            .map(|&peer| (peer, vote_req.clone()))
            .collect();

        Ok(messages)
    }

    /// Create heartbeat message
    fn create_heartbeat(&self, to: Node) -> Result<Option<(Node, Req<Cmd>)>, Failure> {
        let state = self
            .state
            .read()
            .map_err(|_| Failure::System(System::Thread))?;

        if let Role::Leader(_) = state.role {
            Ok(Some((
                to,
                Req::Lead(LeadReq::Pulse {
                    leader: state.volatile.id,
                    epoch: state.persistent.current_term,
                    commit: state.volatile.commit_index,
                }),
            )))
        } else {
            Ok(None)
        }
    }

    /// Flush batch buffer - returns append entries messages
    fn flush_batch(&self) -> Result<Vec<(Node, Req<Cmd>)>, Failure> {
        let mut state = self
            .state
            .write()
            .map_err(|_| Failure::System(System::Thread))?;
        let mut messages = Vec::new();

        // Check if we're leader and have entries to flush
        let should_flush =
            matches!(&state.role, Role::Leader(ls) if !ls.batch_buffer.entries.is_empty());
        if !should_flush {
            return Ok(messages);
        }

        // Extract data we need BEFORE taking mutable reference to role
        let last_index = state.persistent.snapshot_last.index + state.persistent.log.len() as u64;
        let node_id = state.volatile.id;
        let current_term = state.persistent.current_term;
        let cluster_nodes: Vec<Node> = state.cluster.iter().copied().collect();
        let commit_index = state.volatile.commit_index;

        // Extract necessary data before mutating
        let (mut new_entries, last_index, node_id, current_term, cluster_nodes, leader_data) = {
            if let Role::Leader(ref mut leader_state) = state.role {
                if leader_state.batch_buffer.entries.is_empty() {
                    return Ok(messages);
                }

                // Process batch entries
                let mut new_entries = Vec::new();
                for (i, pending) in leader_state.batch_buffer.entries.drain(..).enumerate() {
                    if let Ok(client_req) = Cmd::decode::<ClientReq<Cmd>>(&pending.command) {
                        let entry = Entry {
                            term: current_term,
                            index: last_index + i as u64 + 1,
                            command: client_req.cmd,
                        };
                        new_entries.push(entry);
                    }
                }

                leader_state.batch_buffer.size_bytes = 0;
                leader_state.batch_buffer.oldest_entry = None;

                // Collect leader data we need
                let leader_data: HashMap<Node, u64> = leader_state.next_index.clone();

                (
                    new_entries,
                    last_index,
                    node_id,
                    current_term,
                    cluster_nodes,
                    Some(leader_data),
                )
            } else {
                return Ok(messages);
            }
        };

        // Now we can mutate state.persistent.log
        for entry in &new_entries {
            state.persistent.log.push(entry.clone());
        }

        // Create messages using collected data
        if let Some(next_index_map) = leader_data {
            for peer in cluster_nodes.iter().filter(|&&n| n != node_id) {
                if let Some(&next_idx) = next_index_map.get(peer) {
                    let prev_log = self.get_prev_log(&state, next_idx);

                    messages.push((
                        *peer,
                        Req::Repl(ReplReq::Append {
                            leader: node_id,
                            prev: prev_log,
                            entries: new_entries.clone(),
                            commit: state.volatile.commit_index,
                        }),
                    ));
                }
            }
        }

        Ok(messages)
    }

    /// Get previous log entry for a given next index
    fn get_prev_log(&self, state: &State<Cmd>, next_idx: u64) -> Log {
        if next_idx > 1 {
            let prev_idx = next_idx - 1;
            if prev_idx <= state.persistent.snapshot_last.index {
                state.persistent.snapshot_last
            } else {
                let log_idx = (prev_idx - state.persistent.snapshot_last.index - 1) as usize;
                state
                    .persistent
                    .log
                    .get(log_idx)
                    .map(|e| Log {
                        term: e.term,
                        index: e.index,
                    })
                    .unwrap_or(state.persistent.snapshot_last)
            }
        } else {
            Log { term: 0, index: 0 }
        }
    }

    fn restart_election(
        &self,
        new_timeout: Duration,
        round: u32,
    ) -> Result<Vec<(Node, Req<Cmd>)>, Failure> {
        let mut state = self
            .state
            .write()
            .map_err(|_| Failure::System(System::Thread))?;
        let current_term = state.persistent.current_term;
        let id = state.volatile.id;
        state.persistent.current_term += 1;
        state.persistent.voted_for = Some(state.volatile.id);

        if let Role::Candidate(ref mut candidate_state) = state.role {
            candidate_state.election_timeout = new_timeout;
            candidate_state.election_round = round;
            candidate_state.election_started = Instant::now();
            candidate_state.votes_received.clear();

            // Vote for self again
            candidate_state.votes_received.insert(
                id,
                VoteResp::Grant {
                    voter: id,
                    term: current_term,
                },
            );
        }

        // Increment term and try again

        drop(state);
        self.start_election()
    }

    fn create_retry_append(&self, to: Node) -> Result<Option<(Node, Req<Cmd>)>, Failure> {
        let state = self
            .state
            .read()
            .map_err(|_| Failure::System(System::Thread))?;

        if let Role::Leader(ref leader_state) = state.role {
            if let Some(in_flight_queue) = leader_state.in_flight_appends.get(&to) {
                if let Some(append) = in_flight_queue.front() {
                    return Ok(Some((
                        to,
                        Req::Repl(ReplReq::Append {
                            leader: state.volatile.id,
                            prev: append.prev_log,
                            entries: append.entries.clone(),
                            commit: state.volatile.commit_index,
                        }),
                    )));
                }
            }
        }

        Ok(None)
    }

    fn mark_follower_stale(&self, node: Node) -> Result<(), Failure> {
        let mut state = self
            .state
            .write()
            .map_err(|_| Failure::System(System::Thread))?;

        if let Role::Leader(ref mut leader_state) = state.role {
            if let Some(repl_state) = leader_state.replication_state.get_mut(&node) {
                // Reset to slow replication mode
                repl_state.pipeline_depth = 1;
                repl_state.consecutive_failures = 0;
                repl_state.consecutive_successes = 0;

                // Clear in-flight appends
                leader_state.in_flight_appends.remove(&node);

                // Reset next_index to a more conservative value
                if let Some(match_idx) = leader_state.match_index.get(&node) {
                    leader_state.next_index.insert(node, match_idx + 1);
                }
            }
        }

        Ok(())
    }

    fn expire_read_request(
        &self,
        request_id: Request,
    ) -> Result<Option<(Node, Req<Cmd>)>, Failure> {
        let mut state = self
            .state
            .write()
            .map_err(|_| Failure::System(System::Thread))?;

        if let Role::Leader(ref mut leader_state) = state.role {
            if let Some(_read_req) = leader_state
                .read_index_state
                .pending_reads
                .remove(&request_id)
            {
                // In a real implementation, would need to track client node
                // For now, return None since we can't send response without knowing recipient
            }
        }

        Ok(None)
    }

    fn request_snapshot(&self) -> Result<Vec<(Node, Req<Cmd>)>, Failure> {
        let state = self
            .state
            .read()
            .map_err(|_| Failure::System(System::Thread))?;

        if let Role::Learner(ref learner_state) = state.role {
            if let Some(leader_id) = learner_state.leader_id {
                // Send snapshot request to leader
                return Ok(vec![(leader_id, Req::Mgmt(MgmtReq::Discover))]);
            }
        }

        Ok(vec![])
    }

    fn cleanup_snapshot(&self, id: Snapshot) -> Result<(), Failure> {
        let state = self
            .state
            .read()
            .map_err(|_| Failure::System(System::Thread))?;

        let mut snapshot_store = state
            .snapshot_store
            .write()
            .map_err(|_| Failure::System(System::Thread))?;

        snapshot_store.pending.remove(&id);

        Ok(())
    }

    fn check_snapshot_timeouts(
        &self,
        state: &mut State<Cmd>,
        actions: &mut Vec<TickAction>,
    ) -> Result<(), Failure> {
        let snapshot_store = state
            .snapshot_store
            .read()
            .map_err(|_| Failure::System(System::Thread))?;

        // Check pending snapshots (simplified - would need timestamp tracking)
        let expired_snapshots: Vec<Snapshot> = snapshot_store
            .pending
            .keys()
            .take(0) // For now, don't expire any
            .cloned()
            .collect();

        drop(snapshot_store);

        for snapshot_id in expired_snapshots {
            actions.push(TickAction::CleanupSnapshot { id: snapshot_id });
        }

        Ok(())
    }

    fn get_retry_timeout(&self, state: &State<Cmd>, peer: Node) -> Duration {
        if let Role::Leader(ref leader_state) = state.role {
            if let Some(repl_state) = leader_state.replication_state.get(&peer) {
                // Base timeout with exponential backoff based on failures
                let base = 100;
                let backoff = (1 << repl_state.consecutive_failures.min(5)) as u64;
                return Duration::from_millis(base * backoff);
            }
        }

        Duration::from_millis(100)
    }

    fn get_metrics(&self) -> Metrics {
        Metrics {
            cpu: 0.0,
            mem: 0,
            disk: 0,
            net: 0,
            up_ms: 0,
            fail_rate: 0.0,
        }
    }
}

impl<Cmd: Encode + Decode + Clone> super::State<Req<Cmd>>
    for FineGrained<Cmd>
{
    type Output = Vec<(Node, Resp<Cmd>)>;
    type Error = Failure;

    fn process(&self, command: &[(Node, Req<Cmd>)]) -> Result<Self::Output, Self::Error> {
        let mut responses = Vec::new();
        let mut state = self
            .state
            .write()
            .map_err(|_| Failure::System(System::Thread))?;

        for (node, req) in command {
            match req {
                Req::Vote(vote_req) => {
                    // Handle vote request
                    let resp = self.handle_vote_request(vote_req, &mut state)?;
                    responses.push((*node, Resp::Vote(resp)));
                }
                Req::Lead(lead_req) => {
                    // Handle leadership request
                    let resp = self.handle_lead_request(lead_req, &mut state)?;
                    responses.push((*node, Resp::Lead(resp)));
                }
                Req::Repl(repl_req) => {
                    // Handle replication request
                    let resp = Ok(self.handle_repl_request(repl_req, &mut state))?;
                    responses.push((*node, Resp::Repl(resp)));
                }
                Req::Snap(snap_req) => {
                    // Handle snapshot request
                    let resp = self.handle_snap_request(snap_req, &mut state)?;
                    responses.push((*node, Resp::Snap(resp)));
                }
                Req::Health(health_req) => {
                    // Handle health check request
                    let resp = self.handle_health_request(health_req, &mut state)?;
                    responses.push((*node, Resp::Health(resp)));
                }
                Req::Mgmt(mgmt_req) => {
                    // Handle management request
                    let resp = self.handle_mgmt_request(mgmt_req, &mut state)?;
                    responses.push((*node, Resp::Mgmt(resp)));
                }
                Req::Client(client_req) => {
                    // Handle client command
                    let resp = todo!();
                    responses.push((*node, Resp::Client(resp)));
                }
            }
        }

        let State {
            persistent:
                PersistentState {
                    log,
                    snapshot_last,
                    current_term,
                    voted_for,
                    snapshot,
                    settings,
                },
            volatile:
                VolatileState {
                    id,
                    commit_index,
                    last_applied,
                    last_known_leader,
                },
            ..
        } = &mut *state;
        if *last_applied < *commit_index {
            *last_applied += 1;
            let index = (*last_applied - 1) as usize;
            if let Some(entry) = log.get(index) {
                let _ = self.inner.process(&[(*id, entry.command.clone())]);
            }
        }

        Ok(responses)
    }

    fn tick(&self) -> Result<Vec<(Node, Req<Cmd>)>, Self::Error> {
        let mut state = self
            .state
            .write()
            .map_err(|_| Failure::System(System::Thread))?;

        let now = Instant::now();
        let mut actions = Vec::new();

        match &state.role {
            Role::Follower(follower_state) => {
                // Check for election timeout
                if follower_state.last_heartbeat.elapsed() > follower_state.election_timeout {
                    actions.push(TickAction::StartElection);
                }

                // Check lease expiration
                if let Some(lease) = &follower_state.lease_holder {
                    if now > lease.expires_at {
                        // Lease expired, clear it
                        if let Role::Follower(ref mut fs) = state.role {
                            fs.lease_holder = None;
                        }
                    }
                }
            }

            Role::Candidate(candidate_state) => {
                // Check election timeout
                if candidate_state.election_started.elapsed() > candidate_state.election_timeout {
                    // Election timeout, restart with exponential backoff
                    let new_timeout = Duration::from_millis(
                        candidate_state.election_timeout.as_millis() as u64 * 2,
                    )
                    .min(Duration::from_secs(60)); // Cap at 60 seconds

                    actions.push(TickAction::RestartElection {
                        new_timeout,
                        round: candidate_state.election_round + 1,
                    });
                }
            }

            Role::Leader(leader_state) => {
                // Send periodic heartbeats
                let heartbeat_interval = state.persistent.settings.heartbeat;

                for (peer, last_sent) in &leader_state.last_heartbeat_sent {
                    if last_sent.elapsed() > heartbeat_interval {
                        actions.push(TickAction::SendHeartbeat { to: *peer });
                    }
                }

                // Check for stale followers
                for (peer, repl_state) in &leader_state.replication_state {
                    if let Some(last_failure) = repl_state.last_failure {
                        if last_failure.elapsed() > Duration::from_secs(30)
                            && repl_state.consecutive_failures > 10
                        {
                            actions.push(TickAction::MarkFollowerStale { node: *peer });
                        }
                    }
                }

                // Process batch buffer timeout
                if let Some(oldest) = leader_state.batch_buffer.oldest_entry {
                    if oldest.elapsed() > Duration::from_millis(10) {
                        actions.push(TickAction::FlushBatch);
                    }
                }

                // Retry failed append entries
                for (peer, in_flight) in &leader_state.in_flight_appends {
                    if let Some(oldest) = in_flight.front() {
                        if oldest.sent_at.elapsed() > self.get_retry_timeout(&state, *peer) {
                            actions.push(TickAction::RetryAppend { to: *peer });
                        }
                    }
                }

                // Check read index confirmations
                let read_timeout = Duration::from_millis(500);
                let expired_reads: Vec<Request> = leader_state
                    .read_index_state
                    .pending_reads
                    .iter()
                    .filter(|(_, read)| read.received_at.elapsed() > read_timeout)
                    .map(|(id, _)| *id)
                    .collect();

                for request_id in expired_reads {
                    actions.push(TickAction::ExpireRead { request_id });
                }
            }

            Role::Learner(learner_state) => {
                // Learners don't participate in elections, but track heartbeats
                // Check if we've lost contact with the leader
                if let Some(leader_id) = learner_state.leader_id {
                    // Would need to track last contact time in learner state
                    // For now, just monitor sync progress
                    if learner_state.sync_progress < 0.95 {
                        actions.push(TickAction::RequestSnapshot);
                    }
                }
            }
        }

        // Process pending snapshots
        self.check_snapshot_timeouts(&mut state, &mut actions)?;

        // Apply all collected actions
        drop(state);
        let  action_messages = self.apply_tick_actions(actions)?;

        Ok(action_messages)
    }
}
