<script>
    let {
        currentPage = 1,
        totalPages = 1,
        totalItems = 0,
        itemsPerPage = 50,
        baseUrl = ""
    } = $props();
    
    // Calculate page numbers to show
    $: pageNumbers = (() => {
        const pages = [];
        const showPages = 5; // Number of page links to show
        
        let start = Math.max(1, currentPage - Math.floor(showPages / 2));
        let end = Math.min(totalPages, start + showPages - 1);
        
        // Adjust start if we're near the end
        if (end - start < showPages - 1) {
            start = Math.max(1, end - showPages + 1);
        }
        
        for (let i = start; i <= end; i++) {
            pages.push(i);
        }
        
        return pages;
    })();
    
    $: startItem = (currentPage - 1) * itemsPerPage + 1;
    $: endItem = Math.min(currentPage * itemsPerPage, totalItems);
</script>

<div class="pagination-card">
    <div class="pagination-info">
        <span class="item-count">
            Showing <strong>{startItem}-{endItem}</strong> of <strong>{totalItems}</strong> threads
        </span>
    </div>
    
    <nav class="pagination-nav">
        <a 
            href="{baseUrl}?page=1" 
            class="page-link first"
            class:disabled={currentPage === 1}
            aria-label="First page"
        >
            ⏮️ First
        </a>
        
        <a 
            href="{baseUrl}?page={currentPage - 1}" 
            class="page-link prev"
            class:disabled={currentPage === 1}
            aria-label="Previous page"
        >
            ◀️ Prev
        </a>
        
        {#if pageNumbers[0] > 1}
            <span class="page-ellipsis">...</span>
        {/if}
        
        {#each pageNumbers as pageNum}
            <a 
                href="{baseUrl}?page={pageNum}" 
                class="page-link number"
                class:active={pageNum === currentPage}
                aria-label="Page {pageNum}"
            >
                {pageNum}
            </a>
        {/each}
        
        {#if pageNumbers[pageNumbers.length - 1] < totalPages}
            <span class="page-ellipsis">...</span>
        {/if}
        
        <a 
            href="{baseUrl}?page={currentPage + 1}" 
            class="page-link next"
            class:disabled={currentPage === totalPages}
            aria-label="Next page"
        >
            Next ▶️
        </a>
        
        <a 
            href="{baseUrl}?page={totalPages}" 
            class="page-link last"
            class:disabled={currentPage === totalPages}
            aria-label="Last page"
        >
            Last ⏭️
        </a>
    </nav>
    
    <div class="page-jump">
        <label for="page-select">Jump to page:</label>
        <select 
            id="page-select" 
            value={currentPage}
            onchange={(e) => window.location.href = `${baseUrl}?page=${e.target.value}`}
        >
            {#each Array(totalPages) as _, i}
                <option value={i + 1}>Page {i + 1}</option>
            {/each}
        </select>
    </div>
</div>

<style>
    .pagination-card {
        background: linear-gradient(135deg, rgba(255, 255, 255, 0.05), rgba(255, 255, 255, 0.02));
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 12px;
        padding: 1.5rem;
        backdrop-filter: blur(10px);
        width: 100%;
        display: flex;
        flex-wrap: wrap;
        align-items: center;
        justify-content: space-between;
        gap: 1rem;
    }
    
    .pagination-info {
        font-size: 0.875rem;
        color: rgba(255, 255, 255, 0.7);
    }
    
    .pagination-info strong {
        color: rgba(255, 255, 255, 0.9);
        font-weight: 600;
    }
    
    .pagination-nav {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        flex-wrap: wrap;
    }
    
    .page-link {
        padding: 0.5rem 0.75rem;
        background: rgba(255, 255, 255, 0.05);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 6px;
        color: rgba(255, 255, 255, 0.8);
        text-decoration: none;
        font-size: 0.875rem;
        transition: all 0.2s;
        display: flex;
        align-items: center;
        gap: 0.25rem;
    }
    
    .page-link:hover:not(.disabled) {
        background: rgba(99, 102, 241, 0.2);
        border-color: rgba(99, 102, 241, 0.3);
        color: rgba(255, 255, 255, 0.95);
        transform: translateY(-1px);
    }
    
    .page-link.number {
        min-width: 2.5rem;
        justify-content: center;
        font-weight: 500;
    }
    
    .page-link.active {
        background: rgba(99, 102, 241, 0.3);
        border-color: rgba(99, 102, 241, 0.5);
        color: white;
        font-weight: 700;
    }
    
    .page-link.disabled {
        opacity: 0.4;
        cursor: not-allowed;
    }
    
    .page-link.disabled:hover {
        background: rgba(255, 255, 255, 0.05);
        border-color: rgba(255, 255, 255, 0.1);
        transform: none;
    }
    
    .page-ellipsis {
        color: rgba(255, 255, 255, 0.3);
        padding: 0 0.5rem;
    }
    
    .page-jump {
        display: flex;
        align-items: center;
        gap: 0.75rem;
        font-size: 0.875rem;
    }
    
    .page-jump label {
        color: rgba(255, 255, 255, 0.7);
    }
    
    .page-jump select {
        background: rgba(255, 255, 255, 0.05);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 6px;
        color: rgba(255, 255, 255, 0.9);
        padding: 0.5rem 0.75rem;
        font-size: 0.875rem;
        cursor: pointer;
        transition: all 0.2s;
    }
    
    .page-jump select:hover {
        background: rgba(255, 255, 255, 0.08);
        border-color: rgba(255, 255, 255, 0.2);
    }
    
    .page-jump select:focus {
        outline: none;
        border-color: rgba(99, 102, 241, 0.5);
        box-shadow: 0 0 0 2px rgba(99, 102, 241, 0.2);
    }
    
    .page-jump option {
        background: rgba(0, 0, 0, 0.9);
        color: white;
    }
    
    @media (max-width: 768px) {
        .pagination-card {
            flex-direction: column;
            gap: 1.5rem;
        }
        
        .pagination-nav {
            justify-content: center;
        }
        
        .page-link.first,
        .page-link.last {
            display: none;
        }
    }
</style>