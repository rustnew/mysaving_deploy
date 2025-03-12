
wato@pop-os:~/mysaving$ 
wato@pop-os:~/mysaving$ starkli signer keystore new keystore.json
Enter password: 


Created new encrypted keystore file: /home/wato/mysaving/keystore.json
Public key: 0x06d5144b25a84f9c6f9bb7689ec96ad5b1ae36565643be054d8db669ef79fdad

wato@pop-os:~/mysaving$ export STARKNET_KEYSTORE=$(pwd)/keystore.json

wato@pop-os:~/mysaving$ starkli account oz init account.json
Enter keystore password: 
Created new account config file: /home/wato/mysaving/account.json




Once deployed, this account will be available at:
    0x05fc73dc45b93c7e1d63cebc9ea1b500d830b4d1db3b322df8c9ecd4ca2dddf6

Deploy this account by running:
    starkli account deploy account.json
wato@pop-os:~/mysaving$ export STARKNET_ACCOUNT=$(pwd)/account.json

wato@pop-os:~/mysaving$ starkli account deploy account.json \
    --network=sepolia \
    --strk


    
Enter keystore password: 
The estimated account deployment fee is 0.038419871080623079 STRK. However, to avoid failure, fund at least:
    0.084749715617775250 STRK
to the following address:
    0x05fc73dc45b93c7e1d63cebc9ea1b500d830b4d1db3b322df8c9ecd4ca2dddf6

    
Press [ENTER] once you've funded the address.
Error: ValidationFailure: Resource L1Gas bounds (max amount: 25, max price): 3389988624711010) exceed balance (0).
wato@pop-os:~/mysaving$ 

