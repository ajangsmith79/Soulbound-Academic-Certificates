# 🎓 Soulbound Academic Certificates

A Clarity smart contract for issuing tamper-proof, non-transferable academic credentials on the Stacks blockchain.

## 📚 Overview

This contract enables authorized educational institutions to issue verifiable digital certificates as soulbound tokens that cannot be transferred or sold, ensuring credential authenticity and ownership integrity.

## ✨ Features

- 🏛️ Institution registration and verification
- 📜 Soulbound certificate issuance
- 🔍 Certificate verification
- 🚫 Transfer prevention (soulbound)
- 📋 Comprehensive metadata storage

## 🛠️ Functions

### Administrative
- `register-institution`: Register a new educational institution
- `update-institution`: Update institution details

### Certificate Management
- `issue-certificate`: Issue a new certificate to a recipient
- `get-certificate`: Retrieve certificate details
- `verify-certificate`: Verify certificate ownership
- `has-certificate`: Check if an address owns a specific certificate

## 🔒 Security

- Only contract owner can register/update institutions
- Only verified institutions can issue certificates
- Certificates cannot be transferred (soulbound)

## 📝 Usage Example

```clarity
;; Register an institution
(contract-call? .soulbound-academic-certificates register-institution "Harvard University" "https://harvard.edu")

;; Issue a certificate
(contract-call? .soulbound-academic-certificates issue-certificate 
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 
    "Bachelor of Computer Science" 
    "Graduated with honors" 
    (some "A+")
    "ipfs://QmHash...")
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
```
