Certificate Verification History Feature

Overview
This PR adds a comprehensive Certificate Verification History system to track and audit certificate verification attempts. The feature provides detailed logging of who verified certificates, when, and for what purpose, enhancing the transparency and accountability of the soulbound certificate ecosystem.

Technical Implementation
- **New Data Structures:**
  - `verification-logs` map: Stores detailed verification attempt records
  - `certificate-verification-logs` map: Links certificates to their verification history
  - `verifier-logs` map: Tracks verification history by verifier
  - New error constants for verification-specific errors
  - Verification purpose constants (employment, academic transfer, licensing, etc.)

- **Key Functions Added:**
  - `log-verification`: Records verification attempts with purpose, organization, and notes
  - `get-verification-log`: Retrieves specific verification log details
  - `get-certificate-verification-history`: Gets all verification logs for a certificate
  - `get-verifier-history`: Gets all verifications performed by a specific verifier
  - `get-certificate-verification-stats`: Provides verification statistics
  - `get-verification-purpose-name`: Returns human-readable purpose descriptions
  - `get-institution-verification-trends`: Tracks verification trends by institution

- **Features:**
  - Automatic verification result determination based on certificate status
  - Comprehensive audit trail for compliance and transparency
  - Support for multiple verification purposes (employment, licensing, background checks, etc.)
  - Statistical analysis capabilities for institutions and verifiers
  - Independent feature with no cross-contract dependencies

Testing & Validation
- ✅ Contract passes clarinet check (syntax validation successful)
- ✅ CI/CD pipeline configured with GitHub Actions
- ✅ Clarity v3 compliant with proper error handling and data types
- ✅ Line endings normalized (CRLF → LF)
- ✅ Independent feature implementation (no existing functionality modified)
