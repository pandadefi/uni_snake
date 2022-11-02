import pytest


def test_create_pair(project, factory, token_a, token_b, accounts):
    tx = factory.createPair(token_a, token_b, sender=accounts[0])
    pair_address = list(tx.decode_logs(factory.PairCreated))[0].pair
    pair = project.Pair.at(pair_address)
    token_a.transfer(pair, 10**18, sender=accounts[0])
    token_b.transfer(pair, 10**18, sender=accounts[0])
    pair.mint(accounts[0], sender=accounts[0])
    assert pair.balanceOf(accounts[0]) > 0
