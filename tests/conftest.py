import pytest
import ape
import time
import os
from web3 import Web3, HTTPProvider
from hexbytes import HexBytes


@pytest.fixture(scope="session")
def blueprint(accounts, project):
    w3 = Web3(HTTPProvider(os.getenv("CHAIN_PROVIDER", "http://127.0.0.1:8545")))
    blueprint_bytecode = b"\xFE\x71\x00" + HexBytes(
        project.Pair.contract_type.deployment_bytecode.bytecode
    )
    len_bytes = len(blueprint_bytecode).to_bytes(2, "big")
    deploy_bytecode = HexBytes(
        b"\x61" + len_bytes + b"\x3d\x81\x60\x0a\x3d\x39\xf3" + blueprint_bytecode
    )
    c = w3.eth.contract(abi=[], bytecode=deploy_bytecode)
    deploy_transaction = c.constructor()
    tx_info = {"from": accounts[0].address, "value": 0, "gasPrice": 0}
    tx_hash = deploy_transaction.transact(tx_info)

    return w3.eth.get_transaction_receipt(tx_hash)["contractAddress"]


@pytest.fixture(scope="session")
def factory(blueprint, project, accounts):
    yield accounts[0].deploy(project.Factory, blueprint, accounts[0])


@pytest.fixture(scope="session")
def token_a(deploy_token):
    yield deploy_token("test A")


@pytest.fixture(scope="session")
def token_b(deploy_token):
    yield deploy_token("test B")


@pytest.fixture(scope="session")
def deploy_token(project, accounts):
    def deploy_token(name):
        token = accounts[0].deploy(project.Token, name, name, 18, 10**30)
        token.mint(accounts[0], 10**25, sender=accounts[0])

        return token

    yield deploy_token
