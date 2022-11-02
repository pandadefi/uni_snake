# @version 0.3.7

from vyper.interfaces import ERC20

interface IUniswapV2Factory:
    def feeTo() -> address: view

interface IUniswapV2Callee:
    def uniswapV2Call(_from: address, amount0Out: uint256, amount1Out: uint256, data: Bytes[1024]): nonpayable

## ERC20 variables
NAME: constant(String[42]) = 'Uniswap V2'
SYMBOL: constant(String[20]) = 'UNI-V2'
DECIMALS: constant(uint8) = 18
totalSupply: public(uint256)
balanceOf: public(HashMap[address, uint256])
allowance: public(HashMap[address, HashMap[address, uint256]])
DOMAIN_SEPARATOR: public(bytes32)
PERMIT_TYPE_HASH: constant(bytes32) = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
nonces: public(HashMap[address, uint256])

## UQ112x112 varaibles

Q112: constant(uint224) = 2**112

## Pair varaibles

MINIMUM_LIQUIDITY: constant(uint256) = 10**3
SELECTOR: constant(Bytes[4]) = method_id('transfer(address,uint256)')

FACTORY: immutable(address) 
TOKEN0: immutable(address) 
TOKEN1: immutable(address) 

# uses single storage slot
reserve0: uint112
reserve1: uint112
blockTimestampLast: uint32

price0CumulativeLast: public(uint256)
price1CumulativeLast: public(uint256)
kLast: public(uint256)


## ERC20 events

event Approval:
    owner: indexed(address)
    spender: indexed(address)
    value: uint256
event Transfer:
    _from: indexed(address)
    to: indexed(address)
    value: uint256

## Pair events

event Mint: 
    sender: indexed(address)
    amount0: uint256
    amount1: uint256

event Burn:
    sender: indexed(address)
    amount0: uint256
    amount1: uint256
    to: indexed(address)

event Swap:
    sender: indexed(address)
    amount0In: uint256
    amount1In: uint256
    amount0Out: uint256
    amount1Out: uint256
    to: indexed(address)

event Sync:
    reserve0: uint112
    reserve1: uint112


@external
def __init__(token0: address, token1: address):
    self.DOMAIN_SEPARATOR = keccak256(
            concat(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(convert(NAME, Bytes[42])),
                keccak256(convert('1', Bytes[1])),
                convert(chain.id, bytes32),
                convert(self, bytes32)
            )
        )
    TOKEN0 = token0
    TOKEN1 = token1
    FACTORY = msg.sender 

@external
def token0() -> address:
    return TOKEN0

@external
def token1() -> address:
    return TOKEN1

## ERC20 functions
@internal
def _mint(to: address, _value: uint256):
    self.totalSupply += _value
    self.balanceOf[to] += _value
    log Transfer(empty(address), to, _value)

@internal
def _burn(_from: address, _value: uint256):
    self.balanceOf[_from] -= _value
    self.totalSupply -= _value
    log Transfer(_from, empty(address), _value)
    
@internal
def _approve(owner: address, spender: address, _value: uint256):
    self.allowance[owner][spender] = _value
    log Approval(owner, spender, _value)
    
@internal
def _transfer(_from: address, to: address, _value: uint256):
    self.balanceOf[_from] -= _value
    self.balanceOf[to] += _value
    log Transfer(_from, to, _value)

@external
def approve(spender: address, _value: uint256) -> bool:
    self._approve(msg.sender, spender, _value)
    return True

@external
def transfer(to: address, _value: uint256) -> bool:
    self._transfer(msg.sender, to, _value)
    return True

@external
def transferFrom(_from: address, to: address, _value: uint256) -> bool: 
    if self.allowance[_from][msg.sender] != max_value(int256):
        self.allowance[_from][msg.sender] -= _value
    self._transfer(_from, to, _value)
    return True


@external
def permit(owner: address, spender: address, _value: uint256, deadline: uint256, signature: Bytes[65]) -> bool:
    assert owner != empty(address)  # dev: invalid owner
    assert deadline == 0 or deadline >= block.timestamp  # dev: permit expired
    nonce: uint256 = self.nonces[owner]
    digest: bytes32 = keccak256(
        concat(
            b'\x19\x01',
            self.DOMAIN_SEPARATOR,
            keccak256(
                concat(
                    PERMIT_TYPE_HASH,
                    convert(owner, bytes32),
                    convert(spender, bytes32),
                    convert(_value, bytes32),
                    convert(nonce, bytes32),
                    convert(deadline, bytes32),
                )
            )
        )
    )
    # NOTE: signature is packed as r, s, v
    r: uint256 = convert(slice(signature, 0, 32), uint256)
    s: uint256 = convert(slice(signature, 32, 32), uint256)
    v: uint256 = convert(slice(signature, 64, 1), uint256)
    assert ecrecover(digest, v, r, s) == owner  # dev: invalid signature
    self._approve(owner, spender, _value)
    self.nonces[owner] = nonce + 1
    log Approval(owner, spender, _value)
    return True


## UQ112x112

@internal
@pure
def uqencode(y: uint112) -> uint224:
    return convert(y, uint224) * Q112
@internal
@pure 
def uqdiv(x: uint224, y: uint112) -> uint224:
    return x / convert(y, uint224)

## Pair functions

@external
@view
def getReserves() -> (uint112, uint112, uint32):
    return (self.reserve0, self.reserve1, self.blockTimestampLast)

@internal
def _safeTransfer(token: address, to: address, _value: uint256):
    sucess: bool = ERC20(token).transfer(to, _value, default_return_value=True)
    assert sucess, "UniswapV2: TRANSFER_FAILED"

@internal
def _update(balance0: uint256, balance1: uint256, reserve0: uint112, reserve1: uint112):
    assert balance0 <= max_value(uint112) and balance1 <= max_value(uint112), "UniswapV2: OVERFLOW"

    blockTimestamp: uint32 = convert(block.timestamp % 2**32, uint32)
    timeElapsed: uint32 = 0
    timeElapsed = unsafe_sub(blockTimestamp, self.blockTimestampLast)

    if timeElapsed > 0 and reserve0 != 0 and reserve1 != 0:
        # * never overflows, and + overflow is desired
        timeElapsed256: uint256 = convert(timeElapsed, uint256)
        self.price0CumulativeLast = unsafe_add(self.price0CumulativeLast, convert(self.uqdiv(self.uqencode(reserve1), reserve0), uint256) * timeElapsed256)
        self.price1CumulativeLast = unsafe_add(self.price1CumulativeLast, convert(self.uqdiv(self.uqencode(reserve0), reserve1), uint256) * timeElapsed256)

    self.reserve0 = convert(balance0, uint112)
    self.reserve1 = convert(balance1, uint112)
    self.blockTimestampLast = blockTimestamp
    log Sync(reserve0, reserve1)

@internal
def _mintFee(reserve0: uint112, reserve1: uint112) -> bool:
    feeTo: address = IUniswapV2Factory(FACTORY).feeTo()
    feeOn: bool = feeTo != empty(address)
    kLast: uint256 = self.kLast
    if feeOn:
        if kLast != 0:
            rootK: uint256 = convert(sqrt(convert(reserve0 * reserve1, decimal)), uint256)
            rootKLast: uint256 = convert(sqrt(convert(kLast, decimal)), uint256)
            if rootK > rootKLast:
                numerator: uint256 = self.totalSupply * (rootK - rootKLast)
                denominator: uint256 = rootK * 5 + rootKLast
                liquidity: uint256 = numerator / denominator
                if (liquidity > 0):
                    self._mint(feeTo, liquidity)
            
    elif kLast != 0:
        self.kLast = 0
    return feeOn

@external
@nonreentrant("lock")
def mint(to: address) -> uint256:
    _reserve0: uint112 = self.reserve0
    _reserve1 :uint112 = self.reserve1

    balance0: uint256 = ERC20(TOKEN0).balanceOf(self)
    balance1: uint256 = ERC20(TOKEN1).balanceOf(self)
    amount0: uint256 = balance0 - convert(_reserve0, uint256)
    amount1: uint256 = balance1 - convert(_reserve1, uint256)

    feeOn: bool = self._mintFee(_reserve0, _reserve1)
    _totalSupply: uint256 = self.totalSupply # gas savings, must be defined here since totalSupply can update in _mintFee
    liquidity: uint256 = 0
    if _totalSupply == 0:
        liquidity = convert(sqrt(convert(amount0 * amount1 - MINIMUM_LIQUIDITY, decimal)), uint256)
        self._mint(empty(address), MINIMUM_LIQUIDITY) # permanently lock the first MINIMUM_LIQUIDITY tokens
    else:
        liquidity = min(amount0 * _totalSupply / convert(_reserve0, uint256), amount1 * _totalSupply / convert(_reserve1, uint256))

    assert liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED'
    self._mint(to, liquidity)

    self._update(balance0, balance1, _reserve0, _reserve1)
    if feeOn:
        self.kLast = convert(self.reserve0, uint256) * convert(self.reserve1, uint256) # reserve0 and reserve1 are up-to-date
    log Mint(msg.sender, amount0, amount1)
    return liquidity

@external
@nonreentrant("lock")
def burn(to: address) -> (uint256, uint256):
    _reserve0: uint112 = self.reserve0
    _reserve1 :uint112 = self.reserve1


    balance0: uint256 = ERC20(TOKEN0).balanceOf(self)
    balance1: uint256 = ERC20(TOKEN1).balanceOf(self)
    liquidity: uint256 = self.balanceOf[self]

    feeOn: bool = self._mintFee(_reserve0, _reserve1)
    _totalSupply: uint256 = self.totalSupply # gas savings, must be defined here since totalSupply can update in _mintFee
    amount0: uint256 = liquidity * balance0 / _totalSupply # using balances ensures pro-rata distribution
    amount1: uint256 = liquidity * balance1 / _totalSupply # using balances ensures pro-rata distribution
    assert amount0 > 0 and amount1 > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED'
    self._burn(self, liquidity)
    self._safeTransfer(TOKEN0, to, amount0)
    self._safeTransfer(TOKEN1, to, amount1)
    balance0 = ERC20(TOKEN0).balanceOf(self)
    balance1 = ERC20(TOKEN1).balanceOf(self)

    self._update(balance0, balance1, _reserve0, _reserve1)
    if feeOn:
        self.kLast = convert(self.reserve0, uint256) * convert(self.reserve1, uint256) # reserve0 and reserve1 are up-to-date
    log Burn(msg.sender, amount0, amount1, to)
    return (amount0, amount1)

@external
@nonreentrant("lock")
def swap(amount0Out: uint256, amount1Out: uint256, to: address, data: Bytes[1024]):
    assert amount0Out > 0 or amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT'
    _reserve0: uint112 = self.reserve0
    _reserve1 :uint112 = self.reserve1
    assert amount0Out < convert(_reserve0, uint256) and amount1Out < convert(_reserve1, uint256), 'UniswapV2: INSUFFICIENT_LIQUIDITY'
    balance0: uint256 = 0
    balance1: uint256 = 0

    assert to != TOKEN0 and to != TOKEN1, 'UniswapV2: INVALID_TO'
    
    if amount0Out > 0:
        self._safeTransfer(TOKEN0, to, amount0Out) # optimistically transfer tokens
    
    if amount1Out > 0:
        self._safeTransfer(TOKEN1, to, amount1Out) # optimistically transfer tokens
    if len(data) > 0:
        IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data)
        
    balance0 = ERC20(TOKEN0).balanceOf(self)
    balance1 = ERC20(TOKEN1).balanceOf(self)
    
    amount0In: uint256 = 0
    if balance0 > convert(_reserve0, uint256) - amount0Out:
        amount0In = balance0 - (convert(_reserve0, uint256) - amount0Out)

    amount1In: uint256 = 0 
    if balance1 > convert(_reserve1, uint256) - amount1Out:
        amount1In = balance1 - (convert(_reserve1, uint256) - amount1Out)

    assert amount0In > 0 or amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT'
    balance0Adjusted: uint256 = balance0 * 1000 - (amount0In * 3)
    balance1Adjusted: uint256 = balance1 * 1000 - (amount1In * 3)
    assert balance0Adjusted * balance1Adjusted >= convert(_reserve0, uint256) * convert(_reserve1, uint256) * (1000**2), 'UniswapV2: K'
    
    self._update(balance0, balance1, _reserve0, _reserve1)
    log Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to)

@external
@nonreentrant("lock")
def skim(to: address):
    self._safeTransfer(TOKEN0, to, ERC20(TOKEN0).balanceOf(self) - convert(self.reserve0, uint256))
    self._safeTransfer(TOKEN1, to, ERC20(TOKEN1).balanceOf(self) - convert(self.reserve1, uint256))


@external
@nonreentrant("lock")
def sync():
    self._update(ERC20(TOKEN0).balanceOf(self), ERC20(TOKEN1).balanceOf(self), self.reserve0, self.reserve1)
