from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.math import assert_le, unsigned_div_rem

struct IntArray:
    member elements: felt*
    member word_len: felt # number of 64-bit words
    member byte_len: felt # total number of bytes
end

struct ByteArray:
	member elements: felt*
	member byte_len: felt
end

# Taken from https://github.com/OilerNetwork/fossil
func swap_endian{range_check_ptr, bitwise_ptr : BitwiseBuiltin*}(input: felt, size: felt) -> (output: felt):
    alloc_locals
    let (local output : felt*) = alloc()

    # verifies word fits in 64bits
    assert_le(input, 2**64 - 1)

    # swapped_bytes = ((word & 0xFF00FF00FF00FF00) >> 8) | ((word & 0x00FF00FF00FF00FF) << 8)
    let (left_part, _) = unsigned_div_rem(input, 256)

    assert bitwise_ptr[0].x = left_part
    assert bitwise_ptr[0].y = 0x00FF00FF00FF00FF
    
    assert bitwise_ptr[1].x = input * 256
    assert bitwise_ptr[1].y = 0xFF00FF00FF00FF00
    
    let swapped_bytes = bitwise_ptr[0].x_and_y + bitwise_ptr[1].x_and_y

    # swapped_2byte_pair = ((swapped_bytes & 0xFFFF0000FFFF0000) >> 16) | ((swapped_bytes & 0x0000FFFF0000FFFF) << 16)
    let (left_part2, _) = unsigned_div_rem(swapped_bytes, 2**16)

    assert bitwise_ptr[2].x = left_part2
    assert bitwise_ptr[2].y = 0x0000FFFF0000FFFF
    
    assert bitwise_ptr[3].x = swapped_bytes * 2**16
    assert bitwise_ptr[3].y = 0xFFFF0000FFFF0000
    
    let swapped_2bytes = bitwise_ptr[2].x_and_y + bitwise_ptr[3].x_and_y

    # swapped_4byte_pair = (swapped_2byte_pair >> 32) | ((swapped_2byte_pair << 32) % 2**64)
    let (left_part4, _) = unsigned_div_rem(swapped_2bytes, 2**32)

    assert bitwise_ptr[4].x = swapped_2bytes * 2**32
    assert bitwise_ptr[4].y = 0xFFFFFFFF00000000
    
    let swapped_4bytes = left_part4 + bitwise_ptr[4].x_and_y

    let bitwise_ptr = bitwise_ptr + 5 * BitwiseBuiltin.SIZE

    # Some Shiva-inspired code here
    let (local shift) = pow(2, ((8 - size) * 8))

    if size == 8:
        return (swapped_4bytes)
    else:
        let (shifted_4bytes, _) = unsigned_div_rem(swapped_4bytes, shift)
        return (shifted_4bytes)
    end
end

# Taken from https://github.com/OilerNetwork/fossil
func pow{range_check_ptr}(base: felt, p: felt) -> (res: felt):
    if p == 0:
        return (1)
    end
    let (accumulator) = pow(base=base, p=p-1) 
    return (base * accumulator)
end

func bitshift_right{range_check_ptr}(word: felt, num_bits: felt) -> (shifted: felt):
    assert_le(word, 2**64 - 1) # verifies word fits in 64bits
    assert_le(num_bits, 64) # verifies shifted bits are not above 64
    
    let (divider) = pow(2, num_bits)
    let (left_part, _) = unsigned_div_rem(word, divider)
    return (left_part)
end
