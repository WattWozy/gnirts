use std::sync::Arc;
use std::thread;

const BASE: usize = 256;
const TABLE_SIZE: usize = BASE * BASE;

/// 64-byte aligned container so rows/blocks align with cache lines.
#[repr(align(64))]
pub struct AlignedTable {
    pub data: [u16; TABLE_SIZE],
}

impl AlignedTable {
    pub fn new() -> Self {
        let mut table = AlignedTable {
            data: [0u16; TABLE_SIZE],
        };

        for i in 0..BASE {
            let row_start = i * BASE;
            for j in 0..BASE {
                table.data[row_start + j] = (i * j) as u16;
            }
        }
        table
    }
}
/// Warm the table into cache by reading one element per cache line.
/// Uses volatile reads so the compiler cannot elide them.
pub fn touch_cache(table: &AlignedTable) {
    let mut acc: u64 = 0;
    // number of u16 entries per 64-byte cache line:
    let stride = 64 / std::mem::size_of::<u16>(); // = 32
    let mut idx = 0usize;

    while idx < TABLE_SIZE {
        // volatile read to force actual memory access
        unsafe {
            let v = std::ptr::read_volatile(&table.data[idx]);
            acc = acc.wrapping_add(v as u64);
        }
        idx += stride;
    }

    // Use the accumulator so the compiler can't remove the loop entirely.
    if acc == 0xFFFF_FFFF {
        // impossible normally — keeps optimizer honest
        println!("weird: {}", acc);
    }
}

/// Example worker that simulates many digit lookups using the table.
/// Demonstrates a cache-friendly inner loop (fix a_i outer, iterate b_j inner).
pub fn worker_simulated_multiply(table: &AlignedTable, iterations: usize) -> u64 {
    let mut acc: u64 = 0;
    // simulate choosing a few digits and scanning rows
    for a in 0..8 {
        let row_start = a * BASE;
        for _it in 0..iterations {
            // iterate the row (contiguous) — this is cache friendly
            for b in 0..BASE {
                let prod = table.data[row_start + b] as u64;
                acc = acc.wrapping_add(prod);
            }
        }
    }
    acc
}

fn main() {
    // 1) build table (aligned)
    let table = AlignedTable::new();
    let table = Arc::new(table); // share read-only table across threads

    // 2) warm the table in the main thread first
    touch_cache(&table);

    // 3) spawn threads — each thread touches the table to pull it into local caches
    let n_threads = std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(4);

    let mut handles = Vec::with_capacity(n_threads);
    for t in 0..n_threads {
        let table_clone = Arc::clone(&table);
        let handle = thread::spawn(move || {
            // each thread warms the table into its core-local caches
            touch_cache(&table_clone);
            // do some simulated work using contiguous row scans (cache-friendly)
            let res = worker_simulated_multiply(&table_clone, 4);
            println!("thread {} done, partial acc = {}", t, res);
            res
        });
        handles.push(handle);
    }

    // join threads and combine results to prevent optimization elision
    let mut final_acc: u64 = 0;
    for h in handles {
        final_acc = final_acc.wrapping_add(h.join().unwrap());
    }

    println!("final_acc = {}", final_acc);
}

