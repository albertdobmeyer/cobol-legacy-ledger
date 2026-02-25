"""
Quick settlement test script.

This is a standalone script (not a pytest test) that exercises the settlement
coordinator with the demo batch. It runs 8 pre-defined transfers and prints
results, including the nostro balance check.

What this tests:
    - All 5 banks can process transactions
    - The clearing house records both sides of each settlement
    - NSF rejections are handled gracefully (the oversized transfer fails)
    - Nostro positions net to zero for completed transfers
    - Settlement references are generated correctly

Usage:
    python test_settlement.py
    (Requires seeded data in COBOL-BANKING/data/)
"""
from python.settlement import SettlementCoordinator, DEMO_SETTLEMENT_BATCH

coord = SettlementCoordinator(data_dir='COBOL-BANKING/data')
results = coord.execute_batch_settlement(DEMO_SETTLEMENT_BATCH)

for i, r in enumerate(results, 1):
    sym = 'OK' if r.status == 'COMPLETED' else 'WARN' if r.status == 'PARTIAL_FAILURE' else 'FAIL'
    print(f'[{sym}] #{i} {r.source_bank}:{r.source_account} -> {r.dest_bank}:{r.dest_account} ${r.amount:.2f} | {r.status} | Steps:{r.steps_completed}')
    if r.error:
        print(f'       Error: {r.error}')

summary = coord.get_settlement_summary(results)
print()
print(f"Total: {summary['total_transfers']}  Completed: {summary['completed']}  Failed: {summary['failed']}  Partial: {summary['partial']}")
print(f"Nostro Net: ${summary['nostro_net']:.2f}  Balanced: {summary['clearing_balance_check']}")
print()
for nostro, bal in sorted(summary['nostro_positions'].items()):
    print(f"  {nostro}: {bal:+.2f}")
