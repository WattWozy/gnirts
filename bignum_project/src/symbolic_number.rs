// symbolic_number.rs

use crate::cache::AlignedTable;
use std::sync::Arc;
use std::thread;

#[derive(Clone, Debug)]
pub struct SymbolicNumber {
    pub digits: Vec<u8>, // least significant digit first
}

impl SymbolicNumber {
    pub fn from_u128(mut n: u128) -> Self {
        let mut digits = Vec::new();
        while n > 0 {
            digits.push((n % 256) as u8);
            n /= 256;
        }
        Self { digits }
    }

    pub fn multiply_parallel(&self, other: &Self, table: &Arc<AlignedTable>) -> Self {
        let n = self.digits.len();
        let m = other.digits.len();
        let mut result = vec![0u32; n + m]; // wider to handle local sums

        // determine number of threads
        let n_threads = thread::available_parallelism().map(|n| n.get()).unwrap_or(4);
        let mut handles = Vec::new();
        let block_size = (n + n_threads - 1) / n_threads; // chunk input digits

        for t in 0..n_threads {
            let start = t * block_size;
            let end = ((t + 1) * block_size).min(n);
            if start >= end { continue; }

            let self_digits = self.digits.clone();
            let other_digits = other.digits.clone();
            let table = Arc::clone(&table);

            let handle = thread::spawn(move || {
                let mut partial = vec![0u32; n + m];
                for i in start..end {
                    let a = self_digits[i] as usize;
                    for j in 0..m {
                        let b = other_digits[j] as usize;
                        let prod = table.data[a * 256 + b] as u32;
                        partial[i + j] += prod;
                    }
                }
                partial
            });
            handles.push(handle);
        }

        // accumulate partial results
        for h in handles {
            let partial = h.join().unwrap();
            for i in 0..result.len() {
                result[i] += partial[i];
            }
        }

        // propagate carry across the full result
        let mut carry = 0u32;
        let mut final_digits = Vec::with_capacity(result.len());
        for r in result {
            let total = r + carry;
            final_digits.push((total % 256) as u8);
            carry = total / 256;
        }
        while carry > 0 {
            final_digits.push((carry % 256) as u8);
            carry /= 256;
        }

        SymbolicNumber { digits: final_digits }
    }
}

