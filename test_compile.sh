#!/bin/bash
cd /app
cobc -x -free -I COBOL-BANKING/copybooks COBOL-BANKING/src/VALIDATE.cob -o COBOL-BANKING/bin/VALIDATE > /tmp/validate.log 2>&1
echo "VALIDATE exit code: $?" >> /tmp/validate.log

cobc -x -free -I COBOL-BANKING/copybooks COBOL-BANKING/src/TRANSACT.cob -o COBOL-BANKING/bin/TRANSACT > /tmp/transact.log 2>&1
echo "TRANSACT exit code: $?" >> /tmp/transact.log

cat /tmp/validate.log
echo "---"
cat /tmp/transact.log
