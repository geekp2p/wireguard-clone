// SPDX-License-Identifier: MIT
//
// Simple utility to compute WireGuard public key from private key

package main

import (
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"os"

	"golang.org/x/crypto/curve25519"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <private-key-hex>\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "Computes the WireGuard public key from a private key\n")
		os.Exit(1)
	}

	privateKeyHex := os.Args[1]
	privateKeyBytes, err := hex.DecodeString(privateKeyHex)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error decoding private key hex: %v\n", err)
		os.Exit(1)
	}

	if len(privateKeyBytes) != 32 {
		fmt.Fprintf(os.Stderr, "Private key must be 32 bytes (64 hex characters)\n")
		os.Exit(1)
	}

	// Clamp the private key (as WireGuard does)
	privateKeyBytes[0] &= 248
	privateKeyBytes[31] = (privateKeyBytes[31] & 127) | 64

	var privateKey, publicKey [32]byte
	copy(privateKey[:], privateKeyBytes)

	curve25519.ScalarBaseMult(&publicKey, &privateKey)

	// Output in both formats
	fmt.Printf("Public Key (hex):    %s\n", hex.EncodeToString(publicKey[:]))
	fmt.Printf("Public Key (base64): %s\n", base64.StdEncoding.EncodeToString(publicKey[:]))
}
