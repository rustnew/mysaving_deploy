// tests/test_mysaving.cairo

use starknet::{ContractAddress, contract_address_const, get_caller_address, testing::set_caller_address};
use mysaving::Mysaving::{MysavingImpl, Mysaving};
use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank, CheatTarget};
use mysaving::IMysaving;
use mysaving::IMysavingDispatcher;
use mysaving::IMysavingDispatcherTrait;
use debug::PrintTrait;

// Fonction utilitaire pour déployer le contrat
fn deploy_contract() -> IMysavingDispatcher {
    // Déclarer et déployer le contrat
    let contract_class = declare("Mysaving");
    let contract_address = contract_class.deploy(@ArrayTrait::new()).unwrap();
    
    // Renvoyer le dispatcher
    IMysavingDispatcher { contract_address }
}

#[test]
fn test_deploy() {
    // Déployer le contrat
    let contract = deploy_contract();
    
    // Vérifier que le contrat est déployé avec les bonnes valeurs initiales
    assert(contract.contract_total_supply() == 0_u256, 'total_supply should be 0');
    assert(contract.is_paused() == false, 'contract should not be paused');
}

#[test]
fn test_deposit() {
    // Déployer le contrat
    let contract = deploy_contract();
    let user = contract_address_const::<1>();
    
    // Simuler l'appel du user
    start_prank(CheatTarget::One(contract.contract_address), user);
    
    // Déposer des fonds
    let deposit_amount = 100_u256;
    contract.deposit(deposit_amount);
    
    // Vérifier que le dépôt a fonctionné
    assert(contract.user_balance_of(user) == deposit_amount, 'balance should be updated');
    assert(contract.get_deposit_history(user) == deposit_amount, 'deposit history should be updated');
    assert(contract.contract_total_supply() == deposit_amount, 'total supply should be updated');
    
    stop_prank(CheatTarget::One(contract.contract_address));
}

#[test]
fn test_withdraw() {
    // Déployer le contrat
    let contract = deploy_contract();
    let user = contract_address_const::<1>();
    
    // Simuler l'appel du user
    start_prank(CheatTarget::One(contract.contract_address), user);
    
    // Déposer d'abord des fonds
    let deposit_amount = 100_u256;
    contract.deposit(deposit_amount);
    
    // Retirer une partie des fonds
    let withdraw_amount = 30_u256;
    contract.withdraw(withdraw_amount);
    
    // Vérifier que le retrait a fonctionné
    assert(contract.user_balance_of(user) == deposit_amount - withdraw_amount, 'balance should be updated');
    assert(contract.get_withdraw_history(user) == withdraw_amount, 'withdraw history should be updated');
    assert(contract.contract_total_supply() == deposit_amount - withdraw_amount, 'total supply should be updated');
    
    stop_prank(CheatTarget::One(contract.contract_address));
}

#[test]
fn test_transfer_to() {
    // Déployer le contrat
    let contract = deploy_contract();
    let user1 = contract_address_const::<1>();
    let user2 = contract_address_const::<2>();
    
    // Simuler l'appel du premier utilisateur
    start_prank(CheatTarget::One(contract.contract_address), user1);
    
    // Déposer d'abord des fonds
    let deposit_amount = 100_u256;
    contract.deposit(deposit_amount);
    
    // Transférer des fonds au deuxième utilisateur
    let transfer_amount = 40_u256;
    contract.transfer_to(user2, transfer_amount);
    
    // Vérifier que le transfert a fonctionné
    assert(contract.user_balance_of(user1) == deposit_amount - transfer_amount, 'sender balance should be updated');
    assert(contract.user_balance_of(user2) == transfer_amount, 'recipient balance should be updated');
    
    stop_prank(CheatTarget::One(contract.contract_address));
}

#[test]
fn test_pause_unpause() {
    // Déployer le contrat
    let contract = deploy_contract();
    
    // Le propriétaire du contrat est celui qui l'a déployé
    let owner = get_caller_address();
    let user = contract_address_const::<1>();
    
    // Simuler l'appel de l'utilisateur pour un dépôt initial
    start_prank(CheatTarget::One(contract.contract_address), user);
    contract.deposit(100_u256);
    stop_prank(CheatTarget::One(contract.contract_address));
    
    // Vérifier que le contrat n'est pas en pause
    assert(contract.is_paused() == false, 'contract should not be paused');
    
    // Simuler l'appel du propriétaire pour mettre le contrat en pause
    start_prank(CheatTarget::One(contract.contract_address), owner);
    contract.pause();
    stop_prank(CheatTarget::One(contract.contract_address));
    
    // Vérifier que le contrat est maintenant en pause
    assert(contract.is_paused() == true, 'contract should be paused');
    
    // Vérifier que les opérations ne sont pas possibles pendant la pause
    start_prank(CheatTarget::One(contract.contract_address), user);
    
    // Ces opérations devraient échouer car le contrat est en pause
    let mut success = false;
    match contract.deposit(50_u256) {
        Result::Ok(_) => {},
        Result::Err(_) => { success = true; }
    }
    assert(success, 'deposit should fail when paused');
    
    success = false;
    match contract.withdraw(10_u256) {
        Result::Ok(_) => {},
        Result::Err(_) => { success = true; }
    }
    assert(success, 'withdraw should fail when paused');
    
    stop_prank(CheatTarget::One(contract.contract_address));
    
    // Simuler l'appel du propriétaire pour lever la pause
    start_prank(CheatTarget::One(contract.contract_address), owner);
    contract.unpause();
    stop_prank(CheatTarget::One(contract.contract_address));
    
    // Vérifier que le contrat n'est plus en pause
    assert(contract.is_paused() == false, 'contract should not be paused');
    
    // Vérifier que les opérations sont à nouveau possibles
    start_prank(CheatTarget::One(contract.contract_address), user);
    contract.deposit(50_u256);
    assert(contract.user_balance_of(user) == 150_u256, 'deposit should work after unpause');
    stop_prank(CheatTarget::One(contract.contract_address));
}

#[test]
fn test_get_withdrawable_amount() {
    // Déployer le contrat
    let contract = deploy_contract();
    let user = contract_address_const::<1>();
    
    // Simuler l'appel du user
    start_prank(CheatTarget::One(contract.contract_address), user);
    
    // Au départ, aucun montant ne peut être retiré
    assert(contract.get_withdrawable_amount(user) == 0_u256, 'initial withdrawable should be 0');
    
    // Déposer des fonds
    contract.deposit(100_u256);
    assert(contract.get_withdrawable_amount(user) == 100_u256, 'withdrawable should be 100');
    
    // Retirer une partie des fonds
    contract.withdraw(30_u256);
    assert(contract.get_withdrawable_amount(user) == 70_u256, 'withdrawable should be 70');
    
    // Déposer plus de fonds
    contract.deposit(50_u256);
    assert(contract.get_withdrawable_amount(user) == 120_u256, 'withdrawable should be 120');
    
    stop_prank(CheatTarget::One(contract.contract_address));
}

#[test]
fn test_pause_owner_only() {
    // Déployer le contrat
    let contract = deploy_contract();
    let non_owner = contract_address_const::<5>();
    
    // Simuler l'appel d'un utilisateur qui n'est pas le propriétaire
    start_prank(CheatTarget::One(contract.contract_address), non_owner);
    
    // La tentative de pause devrait échouer
    let mut success = false;
    match contract.pause() {
        Result::Ok(_) => {},
        Result::Err(_) => { success = true; }
    }
    assert(success, 'non-owner should not be able to pause');
    
    stop_prank(CheatTarget::One(contract.contract_address));
}

#[test]
fn test_unpause_owner_only() {
    // Déployer le contrat
    let contract = deploy_contract();
    let owner = get_caller_address();
    let non_owner = contract_address_const::<5>();
    
    // Mettre d'abord le contrat en pause par le propriétaire
    start_prank(CheatTarget::One(contract.contract_address), owner);
    contract.pause();
    stop_prank(CheatTarget::One(contract.contract_address));
    
    // Simuler l'appel d'un utilisateur qui n'est pas le propriétaire
    start_prank(CheatTarget::One(contract.contract_address), non_owner);
    
    // La tentative de lever la pause devrait échouer
    let mut success = false;
    match contract.unpause() {
        Result::Ok(_) => {},
        Result::Err(_) => { success = true; }
    }
    assert(success, 'non-owner should not be able to unpause');
    
    stop_prank(CheatTarget::One(contract.contract_address));
}

#[test]
fn test_balance_after_multiple_operations() {
    // Déployer le contrat
    let contract = deploy_contract();
    let user1 = contract_address_const::<1>();
    let user2 = contract_address_const::<2>();
    
    // Simuler les opérations de user1
    start_prank(CheatTarget::One(contract.contract_address), user1);
    
    // Déposer des fonds
    contract.deposit(100_u256);
    
    // Transférer des fonds à user2
    contract.transfer_to(user2, 30_u256);
    
    // Déposer plus de fonds
    contract.deposit(50_u256);
    
    // Retirer des fonds
    contract.withdraw(20_u256);
    
    // Vérifier le solde final de user1
    assert(contract.user_balance_of(user1) == 100_u256, 'user1 final balance should be 100');
    
    stop_prank(CheatTarget::One(contract.contract_address));
    
    // Vérifier le solde de user2
    assert(contract.user_balance_of(user2) == 30_u256, 'user2 balance should be 30');
    
    // Vérifier l'approvisionnement total
    assert(contract.contract_total_supply() == 130_u256, 'total supply should be 130');
}