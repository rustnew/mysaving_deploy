use starknet::ContractAddress;

#[starknet::interface]
pub trait IMasaving<TContractState> {
    fn get_total_supply(self: @TContractState) -> felt252;
    fn balance_of(self: @TContractState, account: ContractAddress) -> felt252;
    fn allowance( self: @TContractState, owner: ContractAddress, spender: ContractAddress,) -> felt252;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: felt252);
    fn transfer_from( ref self: TContractState,
        sender: ContractAddress,
        recipient: ContractAddress, amount: felt252,
    );
    fn approve(ref self: TContractState, spender: ContractAddress, amount: felt252);
    fn increase_allowance(ref self: TContractState, spender: ContractAddress, added_value: felt252);
    fn decrease_allowance(
        ref self: TContractState, spender: ContractAddress, subtracted_value: felt252,
    );
}

#[starknet::interface]
pub trait IMysaving<TContractState> {
    fn deposit(ref self: TContractState, amount: u256);
    fn withdraw(ref self: TContractState, shares: u256);
    fn user_balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn contract_total_supply(self: @TContractState) -> u256;
    fn get_deposit_history(self: @TContractState, account: ContractAddress) -> u256;
    fn get_withdraw_history(self: @TContractState, account: ContractAddress) -> u256;
    fn get_withdrawable_amount(self: @TContractState, account: ContractAddress) -> u256;
    fn transfer_to(ref self: TContractState, recipient: ContractAddress, amount: u256);
}

#[starknet::contract]
pub mod Mysaving {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };

    #[storage]
    struct Storage{
        total_supply: u256,
        balance_of: Map<ContractAddress, u256>,
        deposit_history: Map<ContractAddress, u256>,
        withdraw_history: Map<ContractAddress, u256>,
        last_deposit_time: Map<ContractAddress, u64>,
        owner: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Deposit: Deposit,
        Withdraw: Withdraw,
        Transfer: Transfer,
        OwnershipTransferred: OwnershipTransferred,
    }

    #[derive(Drop, starknet::Event)]
    struct Deposit {
        user: ContractAddress,
        amount: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        user: ContractAddress,
        amount: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct OwnershipTransferred {
        previous_owner: ContractAddress,
        new_owner: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        // Définir l'appelant comme propriétaire du contrat
        let caller = get_caller_address();
        self.owner.write(caller);
        self.emit(OwnershipTransferred { previous_owner: starknet::contract_address_const::<0>(), new_owner: caller });
    }

    // Modificateur pour restreindre l'accès au propriétaire
    #[generate_trait]
    impl OwnershipChecks of OwnershipChecksTrait {
        fn assert_only_owner(self: @ContractState) {
            let caller = get_caller_address();
            let owner = self.owner.read();
            assert(caller == owner, 'Caller is not the owner');
        }
    }

    #[abi(embed_v0)]
    impl Mysaving of super::IMysaving<ContractState> {
        fn user_balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balance_of.read(account)
        }

        fn contract_total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn get_deposit_history(self: @ContractState, account: ContractAddress) -> u256 {
            self.deposit_history.read(account)
        }

        fn get_withdraw_history(self: @ContractState, account: ContractAddress) -> u256 {
            self.withdraw_history.read(account)
        }

        fn get_withdrawable_amount(self: @ContractState, account: ContractAddress) -> u256 {
            // Un utilisateur ne peut retirer que ce qu'il a déposé moins ce qu'il a déjà retiré
            let total_deposited = self.deposit_history.read(account);
            let total_withdrawn = self.withdraw_history.read(account);
            
            if total_deposited > total_withdrawn {
                total_deposited - total_withdrawn
            } else {
                0_u256
            }
        }

        fn deposit(ref self: ContractState, amount: u256) {
            // Vérifier que le montant est positif
            assert(amount > 0_u256, 'Amount must be positive');
            
            // Obtenir l'adresse de l'appelant
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Ajouter le montant au solde de l'utilisateur
            let current_balance = self.balance_of.read(caller);
            self.balance_of.write(caller, current_balance + amount);
            
            // Mettre à jour l'historique des dépôts
            let deposit_history = self.deposit_history.read(caller);
            self.deposit_history.write(caller, deposit_history + amount);
            
            // Mettre à jour le timestamp du dernier dépôt
            self.last_deposit_time.write(caller, current_time);
            
            // Mettre à jour le total d'approvisionnement
            let current_supply = self.total_supply.read();
            self.total_supply.write(current_supply + amount);
            
            // Émettre un événement de dépôt
            self.emit(Deposit { user: caller, amount, timestamp: current_time });
        }

        fn withdraw(ref self: ContractState, shares: u256) {
            // Vérifier que le montant est positif
            assert(shares > 0_u256, 'Amount must be positive');
            
            // Obtenir l'adresse de l'appelant
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            
            // Calculer le montant maximum que l'utilisateur peut retirer
            let total_deposited = self.deposit_history.read(caller);
            let total_withdrawn = self.withdraw_history.read(caller);
            let _withdrawable = if total_deposited > total_withdrawn {
                total_deposited - total_withdrawn
            } else {
                0_u256
            };
            
            // Vérifier que l'utilisateur peut retirer le montant demandé
            
            // Vérifier que l'utilisateur a un solde suffisant
            let current_balance = self.balance_of.read(caller);
            assert(current_balance >= shares, 'Insufficient balance');
            
            // Soustraire le montant du solde de l'utilisateur
            self.balance_of.write(caller, current_balance - shares);
            
            // Mettre à jour l'historique des retraits
            let withdraw_history = self.withdraw_history.read(caller);
            self.withdraw_history.write(caller, withdraw_history + shares);
            
            // Mettre à jour le total d'approvisionnement
            let current_supply = self.total_supply.read();
            self.total_supply.write(current_supply - shares);
            
            // Émettre un événement de retrait
            self.emit(Withdraw { user: caller, amount: shares, timestamp: current_time });
        }

        fn transfer_to(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            // Vérifier que le montant est positif
            assert(amount > 0_u256, 'Amount must be positive');
            
            // Vérifier que le destinataire n'est pas nul
            assert(recipient != starknet::contract_address_const::<0>(), 'Invalid recipient');
            
            // Obtenir l'adresse de l'appelant
            let caller = get_caller_address();
            
            // Vérifier que l'appelant a un solde suffisant
            let caller_balance = self.balance_of.read(caller);
            assert(caller_balance >= amount, 'Insufficient balance');
            
            // Soustraire du solde de l'appelant
            self.balance_of.write(caller, caller_balance - amount);
            
            // Ajouter au solde du destinataire
            let recipient_balance = self.balance_of.read(recipient);
            self.balance_of.write(recipient, recipient_balance + amount);
            
            // Émettre un événement de transfert
            self.emit(Transfer { from: caller, to: recipient, amount });
        }
    }
}

