# @version 0.3.4

feeTo: public(address)
feeToSetter: public(address)
bluePrint: public(address)

getPair: public(HashMap[address, HashMap[address, address]])
allPairs: public(address[1_000_000])
allPairsLength: public(uint256)

event PairCreated:
    token0: indexed(address)
    token1: indexed(address)
    pair: address
    length: uint256

@external
def __init__(bluePrint: address, _feeToSetter: address):
    self.bluePrint = bluePrint
    self.feeToSetter = _feeToSetter

@external
def createPair(tokenA: address, tokenB: address) -> address:
    assert tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES'
    token0: address = empty(address)
    token1: address = empty(address)

    if convert(tokenA, uint256) < convert(tokenB, uint256):
        token0 = tokenA
        token1 = tokenB
    else:
        token0 = tokenB
        token1 = tokenA
    assert token0 != empty(address), 'UniswapV2: ZERO_ADDRESS'
    assert self.getPair[token0][token1] == empty(address), 'UniswapV2: PAIR_EXISTS'
    salt: bytes32 = keccak256(_abi_encode(token0, token1))
    pair: address = create_from_blueprint(self.bluePrint, token0, token1, salt=salt)
    self.getPair[token0][token1] = pair
    self.getPair[token1][token0] = pair
    self.allPairs[self.allPairsLength] = pair
    self.allPairsLength += 1
    log PairCreated(token0, token1, pair, self.allPairsLength)

    return pair

@external
def setFeeTo(_feeTo: address):
    assert msg.sender == self.feeToSetter, 'UniswapV2: FORBIDDEN'
    self.feeTo = _feeTo

@external
def setFeeToSetter(_feeToSetter: address):
    assert msg.sender == self.feeToSetter, 'UniswapV2: FORBIDDEN'
    self.feeToSetter = _feeToSetter
