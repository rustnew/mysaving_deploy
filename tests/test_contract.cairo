use starknet::ContractAddress;

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

use starknet::ContractAddress;
use snforge_std::{declare, CheatTarget, start_prank, stop_prank};
use mysaving::IMysavingDispatcher;
use mysaving::IMysavingDispatcherTrait;
use mysaving::IMysavingSafeDispatcher;
use mysaving::IMysavingSafeDispatcherTrait;
use snforge_std::prelude::*;

//
fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}
// Fonction pour obtenir une adresse de test
fn get_test_address() -> ContractAddress {
    starknet::contract_address_const::<0x123>()
}

#[test]
fn test_deposit() {
    // Déployer le contrat
    let contract_address = deploy_contract("Mysaving");
    let dispatcher = IMysavingDispatcher { contract_address };
    
    // Adresse de test pour simuler un appelant
    let user = get_test_address();
    
    // Simuler un appel depuis l'adresse de test
    start_prank(CheatTarget::ContractAddress(contract_address), user);
    
    // Vérifier le solde initial
    let balance_before = dispatcher.user_balance_of(user);
    assert(balance_before == 0_u256, 'Initial balance should be 0');
    
    // Effectuer un dépôt
    let deposit_amount = 100_u256;
    dispatcher.deposit(deposit_amount);
    
    // Vérifier le solde après dépôt
    let balance_after = dispatcher.user_balance_of(user);
    assert(balance_after == deposit_amount, 'Balance should match deposit');
    
    // Vérifier l'historique de dépôt
    let deposit_history = dispatcher.get_deposit_history(user);
    assert(deposit_history == deposit_amount, 'Deposit history incorrect');
    
    // Arrêter la simulation
    stop_prank(CheatTarget::ContractAddress(contract_address));
}

#[test]
fn test_withdraw() {
    // Déployer le contrat
    let contract_address = deploy_contract("Mysaving");
    let dispatcher = IMysavingDispatcher { contract_address };
    
    // Adresse de test pour simuler un appelant
    let user = get_test_address();
    
    // Simuler un appel depuis l'adresse de test
    start_prank(CheatTarget::ContractAddress(contract_address), user);
    
    // D'abord faire un dépôt
    let deposit_amount = 100_u256;
    dispatcher.deposit(deposit_amount);
    
    // Effectuer un retrait
    let withdraw_amount = 50_u256;
    dispatcher.withdraw(withdraw_amount);
    
    // Vérifier le solde après retrait
    let balance_after = dispatcher.user_balance_of(user);
    assert(balance_after == deposit_amount - withdraw_amount, 'Balance after withdraw incorrect');
    
    // Vérifier l'historique de retrait
    let withdraw_history = dispatcher.get_withdraw_history(user);
    assert(withdraw_history == withdraw_amount, 'Withdraw history incorrect');
    
    // Arrêter la simulation
    stop_prank(CheatTarget::ContractAddress(contract_address));
}

#[test]
fn test_transfer_to() {
    // Déployer le contrat
    let contract_address = deploy_contract("Mysaving");
    let dispatcher = IMysavingDispatcher { contract_address };
    
    // Adresses de test pour simuler un appelant et un destinataire
    let sender = get_test_address();
    let recipient = starknet::contract_address_const::<0x456>();
    
    // Simuler un appel depuis l'adresse de l'expéditeur
    start_prank(CheatTarget::ContractAddress(contract_address), sender);
    
    // Faire un dépôt d'abord
    let deposit_amount = 100_u256;
    dispatcher.deposit(deposit_amount);
    
    // Effectuer un transfert
    let transfer_amount = 30_u256;
    dispatcher.transfer_to(recipient, transfer_amount);
    
    // Vérifier le solde de l'expéditeur
    let sender_balance = dispatcher.user_balance_of(sender);
    assert(sender_balance == deposit_amount - transfer_amount, 'Sender balance incorrect');
    
    // Vérifier le solde du destinataire
    let recipient_balance = dispatcher.user_balance_of(recipient);
    assert(recipient_balance == transfer_amount, 'Recipient balance incorrect');
    
    // Arrêter la simulation
    stop_prank(CheatTarget::ContractAddress(contract_address));
}

#[test]
#[feature("safe_dispatcher")]
fn test_cannot_deposit_zero() {
    // Déployer le contrat
    let contract_address = deploy_contract("Mysaving");
    let safe_dispatcher = IMysavingSafeDispatcher { contract_address };
    
    // Adresse de test
    let user = get_test_address();
    
    // Simuler un appel depuis l'adresse de test
    start_prank(CheatTarget::ContractAddress(contract_address), user);
    
    // Tenter un dépôt de zéro
    match safe_dispatcher.deposit(0_u256) {
        Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'Amount must be positive', *panic_data.at(0));
        }
    };
    
    // Arrêter la simulation
    stop_prank(CheatTarget::ContractAddress(contract_address));
}

#[test]
fn test_get_withdrawable_amount() {
    // Déployer le contrat
    let contract_address = deploy_contract("Mysaving");
    let dispatcher = IMysavingDispatcher { contract_address };
    
    // Adresse de test
    let user = get_test_address();
    
    // Simuler un appel depuis l'adresse de test
    start_prank(CheatTarget::ContractAddress(contract_address), user);
    
    // Faire plusieurs opérations
    dispatcher.deposit(100_u256);
    dispatcher.withdraw(30_u256);
    dispatcher.deposit(50_u256);
    
    // Vérifier le montant retirable
    let withdrawable = dispatcher.get_withdrawable_amount(user);
    assert(withdrawable == 120_u256, 'Incorrect withdrawable amount');
    
    // Arrêter la simulation
    stop_prank(CheatTarget::ContractAddress(contract_address));
}

#[test]
fn test_contract_total_supply() {
    // Déployer le contrat
    let contract_address = deploy_contract("Mysaving");
    let dispatcher = IMysavingDispatcher { contract_address };
    
    // Adresses de test
    let user1 = get_test_address();
    let user2 = starknet::contract_address_const::<0x456>();
    
    // Simuler des dépôts de différents utilisateurs
    start_prank(CheatTarget::ContractAddress(contract_address), user1);
    dispatcher.deposit(100_u256);
    stop_prank(CheatTarget::ContractAddress(contract_address));
    
    start_prank(CheatTarget::ContractAddress(contract_address), user2);
    dispatcher.deposit(200_u256);
    stop_prank(CheatTarget::ContractAddress(contract_address));
    
    // Vérifier le total supply
    let total_supply = dispatcher.contract_total_supply();
    assert(total_supply == 300_u256, 'Incorrect total supply');
}

#[test]
#[feature("safe_dispatcher")]
fn test_cannot_withdraw_more_than_balance() {
    // Déployer le contrat
    let contract_address = deploy_contract("Mysaving");
    let safe_dispatcher = IMysavingSafeDispatcher { contract_address };
    
    // Adresse de test
    let user = get_test_address();
    
    // Simuler un appel depuis l'adresse de test
    start_prank(CheatTarget::ContractAddress(contract_address), user);
    
    // Déposer un montant
    safe_dispatcher.deposit(50_u256).unwrap();
    
    // Tenter de retirer plus que le solde
    match safe_dispatcher.withdraw(60_u256) {
        Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'Insufficient balance', *panic_data.at(0));
        }
    };
    
    // Arrêter la simulation
    stop_prank(CheatTarget::ContractAddress(contract_address));
}