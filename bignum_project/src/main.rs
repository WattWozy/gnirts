use std::sync::Arc;
mod cache;
mod symbolic_number;
mod decimal_conversion;

use cache::AlignedTable;
use decimal_conversion::{string_to_symbolic_number, symbolic_number_to_string};

fn main() {
    let table = Arc::new(AlignedTable::new());

    // 1️⃣ Warm up table
    cache::touch_cache(&table);
    let _ = cache::worker_simulated_multiply(&table, 1_000_000);

    // 2️⃣ Prepare numbers
    let nums = [
        "1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890",
        "9876543210987654321098765432109876543210987654321098765432109876543210987654321098765432109876543210",
    ];

    let symbolic_nums: Vec<_> = nums.iter()
        .map(|s| string_to_symbolic_number(s))
        .collect();

    // 3️⃣ Multiply
    let product = symbolic_nums[0].multiply_parallel(&symbolic_nums[1], &table);

    // 4️⃣ Convert back to decimal
    let result_str = symbolic_number_to_string(&product);
    println!("num1 x num2 = {}", result_str);
}

