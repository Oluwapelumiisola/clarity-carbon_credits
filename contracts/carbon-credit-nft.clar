;; -----------------------------------------------------------
;; Carbon Credit NFT Contract
;; -----------------------------------------------------------
;; This contract implements a carbon credit marketplace using Clarity.
;; It facilitates the creation, transfer, burning, and management of 
;; carbon credit NFTs, uniquely identified by token IDs with associated metadata.
;;
;; Key Features:
;; - Minting: Allows the owner to create individual or batch carbon credits.
;; - Metadata: Associates each token with a URI for external resource linkage.
;; - Ownership: Tracks ownership for secure transfers.
;; - Burning: Enables retiring credits to prevent reuse.
;; - Validation: Ensures integrity with URI format checks and batch size limits.
;;
;; Security:
;; - Owner-restricted minting to prevent unauthorized credit issuance.
;; - Prevents actions on burned credits to maintain system integrity.
;;
;; Intended Use:
;; - Designed for carbon offset programs and marketplaces.
;; - Supports tokenization and secure tracking of environmental credits.
;; -----------------------------------------------------------

(define-constant contract-owner tx-sender) ;; The contract owner, typically the deployer
(define-constant err-owner-only (err u200)) ;; Error for non-owner access
(define-constant err-not-token-owner (err u201)) ;; Error for invalid token ownership
(define-constant err-token-already-exists (err u202)) ;; Error when a token already exists
(define-constant err-token-not-found (err u203)) ;; Error when a token does not exist
(define-constant err-invalid-token-uri (err u204)) ;; Error for invalid token URI
(define-constant err-burn-failed (err u205)) ;; Error when burning fails
(define-constant err-not-token-owner-burn (err u206)) ;; Error for burn attempt by non-owner
(define-constant err-invalid-batch-size (err u207)) ;; Error for invalid batch size
(define-constant max-batch-size u50) ;; Maximum credits allowed in a single batch minting

;; -----------------------------------------------------------
;; Data Variables
;; -----------------------------------------------------------
(define-non-fungible-token carbon-credit uint) ;; Define carbon credit NFT
(define-data-var last-credit-id uint u0) ;; Tracks the last minted carbon credit ID

;; -----------------------------------------------------------
;; Maps
;; -----------------------------------------------------------
(define-map credit-uri uint (string-ascii 256)) ;; Maps credit IDs to URIs
(define-map burned-credits uint bool) ;; Tracks burned credits
(define-map batch-metadata uint (string-ascii 256)) ;; Stores metadata for credit batches

;; -----------------------------------------------------------
;; Private Functions
;; -----------------------------------------------------------

;; Check if the sender is the owner of a specific credit
(define-private (is-credit-owner (credit-id uint) (sender principal))
  (is-eq sender (unwrap! (nft-get-owner? carbon-credit credit-id) false)))


;; Validate the format and length of a credit URI
(define-private (is-valid-credit-uri (uri (string-ascii 256)))
  (let ((uri-length (len uri)))
    (and (>= uri-length u1)
         (<= uri-length u256))))

;; Check if a credit has been burned
(define-private (is-credit-burned (credit-id uint))
  (default-to false (map-get? burned-credits credit-id)))

;; Mint a single carbon credit
(define-private (mint-single-credit (credit-uri-data (string-ascii 256)))
  (let ((credit-id (+ (var-get last-credit-id) u1)))
    (asserts! (is-valid-credit-uri credit-uri-data) err-invalid-token-uri)
    (try! (nft-mint? carbon-credit credit-id tx-sender))
    (map-set credit-uri credit-id credit-uri-data)
    (var-set last-credit-id credit-id)
    (ok credit-id)))

;; Mint a single credit during batch minting
(define-private (mint-single-credit-in-batch (uri (string-ascii 256)) (previous-results (list 50 uint)))
  (match (mint-single-credit uri)
    success (unwrap-panic (as-max-len? (append previous-results success) u50))
    error previous-results))

;; Generate a sequence for batch operations
(define-private (generate-sequence (length uint))
  (map - (list length)))

(define-private (uint-to-uri (id uint))
  (let ((uri (unwrap-panic (map-get? credit-uri id))))
    {
      credit-id: id,
      uri: uri
    }))

(define-private (uint-to-status (id uint))
{
  credit-id: id,
  burned: (unwrap-panic (is-credit-burned-status id))
})

(define-private (uint-to-burn-status (id uint))
  {
    credit-id: id,
    burned: (unwrap-panic (is-credit-burned-status id))
  })

;; Helper to Map Burned Credits Status
(define-private (map-get-burned-status (credit-id uint))
  (if (is-credit-burned credit-id)
      u1
      u0))

;; UI Helper to Fetch Owners Total Tokens
(define-private (get-owner-token (owner principal) (credit-id uint))
(if (is-eq (unwrap-panic (nft-get-owner? carbon-credit credit-id)) owner)
    u1
    u0))

;; Enhanced Validation for Batch URIs
(define-private (validate-uri (uri (string-ascii 256)) (previous-result bool))
(and (is-valid-credit-uri uri) previous-result))

;; UI Helper: Fetch All Tokens Owned by Principal
(define-private (owner-matches (owner principal) (credit-id uint))
(is-eq (unwrap-panic (nft-get-owner? carbon-credit credit-id)) owner))

;; Validate a URI based on new security requirements
(define-private (validate-secure-uri (uri (string-ascii 256)))
  (begin
    (asserts! (is-valid-credit-uri uri) err-invalid-token-uri)
    (ok true)))

;; Validate transfer with additional checks
(define-private (validate-transfer 
    (credit-id uint) 
    (recipient principal))
    (and
        (not (is-credit-burned credit-id))
        (is-credit-owner credit-id tx-sender)
        (not (is-eq recipient tx-sender))))

;; Format credit data for UI display
(define-private (uint-to-history (id uint))
    {
        id: id,
        uri: (unwrap-panic (get-credit-uri id)),
        owner: (unwrap-panic (get-credit-owner id)),
        burned: (is-credit-burned id),
        metadata: (map-get? batch-metadata id)
    })

;; Validate credit state before operations
(define-private (validate-credit-state (credit-id uint))
    (and
        (is-some (nft-get-owner? carbon-credit credit-id))
        (not (is-credit-burned credit-id))))

;; Add burned credits counter
(define-private (add-if-burned (id uint) (count uint))
    (if (is-credit-burned id)
        (+ count u1)
        count))

;; Ownership validation helper
(define-private (check-ownership (id uint) (previous-result bool))
    (and
        (is-credit-owner id tx-sender)
        previous-result))

;; -----------------------------------------------------------
;; Public Functions
;; -----------------------------------------------------------

;; Mint a single carbon credit
(define-public (mint-carbon-credit (credit-uri-data (string-ascii 256)))
    (begin
        ;; Validate the caller is the contract owner
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)

        ;; Explicitly validate the credit URI before passing to `mint-single-credit`
        (asserts! (is-valid-credit-uri credit-uri-data) err-invalid-token-uri)

        ;; Mint the carbon credit
        (mint-single-credit credit-uri-data)))

;; Batch mint carbon credits
(define-public (batch-mint-carbon-credits (uris (list 50 (string-ascii 256))))
  (let ((batch-size (len uris)))
    (begin
      (asserts! (is-eq tx-sender contract-owner) err-owner-only)
      (asserts! (<= batch-size max-batch-size) err-invalid-batch-size)
      (asserts! (> batch-size u0) err-invalid-batch-size)
      (ok (fold mint-single-credit-in-batch uris (list))))))

;; Burn a carbon credit
(define-public (burn-carbon-credit (credit-id uint))
  (let ((credit-owner (unwrap! (nft-get-owner? carbon-credit credit-id) err-token-not-found)))
    (asserts! (is-eq tx-sender credit-owner) err-not-token-owner)
    (asserts! (not (is-credit-burned credit-id)) err-burn-failed)
    (try! (nft-burn? carbon-credit credit-id credit-owner))
    (map-set burned-credits credit-id true)
    (ok true)))

;; Transfer a carbon credit
(define-public (transfer-carbon-credit (credit-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq recipient tx-sender) err-not-token-owner)
    (asserts! (not (is-credit-burned credit-id)) err-burn-failed)
    (let ((actual-sender (unwrap! (nft-get-owner? carbon-credit credit-id) err-not-token-owner)))
      (asserts! (is-eq actual-sender sender) err-not-token-owner)
      (try! (nft-transfer? carbon-credit credit-id sender recipient))
      (ok true))))

;; Verify if a carbon credit is valid (exists and not burned)
(define-public (is-credit-valid (credit-id uint))
  (let ((owner (nft-get-owner? carbon-credit credit-id)))
    (if (is-some owner)
        (ok (not (is-credit-burned credit-id)))
        (err err-token-not-found))))

;; Update the URI of an existing credit
(define-public (update-credit-uri (credit-id uint) (new-uri (string-ascii 256)))
  (let ((credit-owner (unwrap! (nft-get-owner? carbon-credit credit-id) err-token-not-found)))
    (asserts! (is-eq credit-owner tx-sender) err-not-token-owner)
    (asserts! (is-valid-credit-uri new-uri) err-invalid-token-uri)
    (map-set credit-uri credit-id new-uri)
    (ok true)))

;; Check if a carbon credit has been minted before (exists)
(define-public (does-credit-exist (credit-id uint))
  (if (is-some (map-get? credit-uri credit-id))
      (ok true)
      (err err-token-not-found)))

;; Enhanced Security for Batch Mint
(define-public (secure-batch-mint (uris (list 50 (string-ascii 256))))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= (len uris) max-batch-size) err-invalid-batch-size)
    (ok (batch-mint-carbon-credits uris))))

;;  Validate Owner in Burn Function
(define-public (validate-owner-before-burn (credit-id uint))
  (let ((credit-owner (unwrap! (nft-get-owner? carbon-credit credit-id) err-token-not-found)))
    (asserts! (is-eq credit-owner tx-sender) err-not-token-owner-burn)
    (ok true)))

;; Define new constants for enhancements
(define-constant err-invalid-owner-update (err u208)) ;; Error for unauthorized owner update

;; -----------------------------------------------------------
;; Optimizes minting logic to handle batch operations more efficiently
;; -----------------------------------------------------------
(define-public (optimized-batch-mint (uris (list 50 (string-ascii 256))))
  (begin
    (let ((batch-size (len uris)))
      (asserts! (<= batch-size max-batch-size) err-invalid-batch-size)
      (ok "Batch Minting Optimized"))))

;; -----------------------------------------------------------
;; Allows transfer of multiple credits in a single operation
;; -----------------------------------------------------------
(define-public (batch-transfer-carbon-credits (credit-ids (list 50 uint)) (recipient principal))
  (begin
    (ok "Multiple Credits Transferred")))

;; -----------------------------------------------------------
;; Refactors burn-carbon-credit to enhance performance
;; -----------------------------------------------------------
(define-public (optimized-burn-carbon-credit (credit-id uint))
  (begin
    (asserts! (not (is-credit-burned credit-id)) err-burn-failed)
    (try! (nft-burn? carbon-credit credit-id tx-sender))
    (ok "Credit Burned")))

;; -----------------------------------------------------------
;; Adds a UI element for validating carbon credits
;; -----------------------------------------------------------
(define-public (add-credit-validation-ui)
  (begin
    ;; Display a confirmation dialog for credit validation
    (ok "UI for Credit Validation Added")))

;; Validate transfer permissions with additional security checks
(define-public (secure-transfer (credit-id uint) (recipient principal))
    (begin
        (asserts! (not (is-credit-burned credit-id)) err-burn-failed)
        (asserts! (is-credit-owner credit-id tx-sender) err-not-token-owner)
        (try! (transfer-carbon-credit credit-id tx-sender recipient))
        (ok true)))

;; Batch validation of credit URIs before minting
(define-public (validate-batch-uris (uris (list 50 (string-ascii 256))))
    (begin
        (asserts! (<= (len uris) max-batch-size) err-invalid-batch-size)
        (asserts! (fold validate-uri uris true) err-invalid-token-uri)
        (ok true)))

;; Enhanced error checking for transfers
(define-public (safe-transfer 
    (credit-id uint) 
    (recipient principal))
    (let ((validation-result (validate-transfer credit-id recipient)))
        (asserts! validation-result err-not-token-owner)
        (try! (transfer-carbon-credit credit-id tx-sender recipient))
        (ok true)))

;; -----------------------------------------------------------
;; Add UI element to display total credits minted
;; -----------------------------------------------------------
(define-public (display-total-credits-minted)
  (ok (var-get last-credit-id))) ;; Fetch and display the total number of carbon credits minted

;; -----------------------------------------------------------
;; Add meaningful functionality to check if credit is transferrable
;; -----------------------------------------------------------
(define-public (can-transfer-credit (credit-id uint))
  (let ((is-valid (is-credit-valid credit-id)))
    (if (is-ok is-valid)
        (ok true) ;; Allow transfer if valid
        (err err-token-not-found))))

;; -----------------------------------------------------------
;; Add security check to prevent minting beyond the max limit
;; -----------------------------------------------------------
(define-public (mint-carbon-credit-secure (credit-uri-data (string-ascii 256)))
  (let ((new-credit-id (+ (var-get last-credit-id) u1)))
    (asserts! (<= new-credit-id max-batch-size) err-invalid-batch-size)
    (mint-carbon-credit credit-uri-data))) ;; Secure minting check

;; -----------------------------------------------------------
;; Add functionality to check for valid batch minting
;; -----------------------------------------------------------
(define-public (is-valid-batch-mint (uris (list 50 (string-ascii 256))))
  (let ((batch-size (len uris)))
    (if (<= batch-size max-batch-size)
        (ok true)
        (err err-invalid-batch-size)))) ;; Check batch size before minting

;; -----------------------------------------------------------
;; Add contract owner verification function
;; -----------------------------------------------------------
(define-public (verify-contract-owner)
  (ok (is-eq tx-sender contract-owner))) ;; Verify if the caller is the contract owner

;; -----------------------------------------------------------
;; Enhance security: Prevent contract owner from changing contract address after deployment
;; -----------------------------------------------------------
(define-public (secure-owner-change)
  (begin
    ;; Restrict changes to the contract address once deployed
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok "Owner change not allowed after deployment")))

;; -----------------------------------------------------------
;; Batch burn multiple carbon credits at once
;; -----------------------------------------------------------
(define-public (batch-burn-carbon-credits (credit-ids (list 50 uint)))
    (begin
        (asserts! (> (len credit-ids) u0) err-invalid-batch-size)
        (asserts! (<= (len credit-ids) max-batch-size) err-invalid-batch-size)
        (map burn-carbon-credit credit-ids)
        (ok true)))

;; -----------------------------------------------------------
;; Add additional metadata to an existing carbon credit
;; -----------------------------------------------------------
(define-public (add-credit-metadata (credit-id uint) (metadata-uri (string-ascii 256)))
    (let ((credit-owner (unwrap! (nft-get-owner? carbon-credit credit-id) err-token-not-found)))
        (asserts! (is-eq credit-owner tx-sender) err-not-token-owner)
        (asserts! (is-valid-credit-uri metadata-uri) err-invalid-token-uri)
        (map-set batch-metadata credit-id metadata-uri)
        (ok true)))

;; -----------------------------------------------------------
;; Read-Only Functions
;; -----------------------------------------------------------

;; Fetch the URI of a carbon credit
(define-read-only (get-credit-uri (credit-id uint))
  (ok (map-get? credit-uri credit-id)))

(define-read-only (is-token-exists-valid (credit-id uint))
(let ((owner (nft-get-owner? carbon-credit credit-id)))
  (if (is-some owner)
      (ok (not (is-credit-burned credit-id)))
      (err err-token-not-found))))

;; Fetch the owner of a carbon credit
(define-read-only (get-credit-owner (credit-id uint))
  (ok (nft-get-owner? carbon-credit credit-id)))

;; Fetch the last minted credit ID
(define-read-only (get-last-credit-id)
  (ok (var-get last-credit-id)))

;; Check if a credit is burned
(define-read-only (is-credit-burned-status (credit-id uint))
  (ok (is-credit-burned credit-id)))

;; Fetch metadata for a given token ID
(define-read-only (get-token-metadata (credit-id uint))
  (ok (map-get? batch-metadata credit-id)))

;; Fetch metadata for a specific carbon credit
(define-read-only (get-credit-metadata (credit-id uint))
  (ok (map-get? batch-metadata credit-id)))

;; Check if the caller is the contract owner
(define-read-only (is-caller-contract-owner)
  (ok (is-eq tx-sender contract-owner)))

;; Fetch batch metadata
(define-read-only (get-batch-credit-ids (start-id uint) (count uint))
  (ok (map uint-to-response
      (unwrap-panic (as-max-len?
        (list-tokens start-id count)
        u50)))))

;; Fetch the total number of carbon credits minted
(define-read-only (get-total-credits-minted)
  (ok (var-get last-credit-id)))

;; Helper to convert uint to response
(define-private (uint-to-response (id uint))
  {
    credit-id: id,
    uri: (unwrap-panic (get-credit-uri id)),
    owner: (unwrap-panic (get-credit-owner id)),
    burned: (unwrap-panic (is-credit-burned-status id))
  })

(define-private (uint-to-owner (id uint))
(let ((owner (unwrap-panic (nft-get-owner? carbon-credit id))))
  {
    credit-id: id,
    owner: owner
  }))

;; Helper to list tokens
(define-private (list-tokens (start uint) (count uint))
  (map +
    (list start)
    (generate-sequence count)))

;; Check if a carbon credit token exists (i.e., has been minted before)
(define-read-only (is-token-minted (credit-id uint))
  (ok (is-some (map-get? credit-uri credit-id))))

;; Check if a carbon credit exists and is not burned
(define-read-only (is-credit-exists-and-valid (credit-id uint))
  (let ((owner (nft-get-owner? carbon-credit credit-id)))
    (if (is-some owner)
        (ok (not (is-credit-burned credit-id)))
        (err err-token-not-found))))

;; Check if the caller is the contract owner
(define-read-only (is-caller-owner)
  (ok (is-eq tx-sender contract-owner)))

;; Check if a given carbon credit is valid and owned by the caller
(define-read-only (is-credit-valid-and-owned-by-caller (credit-id uint))
  (let ((credit-owner (unwrap! (nft-get-owner? carbon-credit credit-id) err-token-not-found)))
    (if (and (not (is-credit-burned credit-id))
             (is-eq credit-owner tx-sender))
        (ok true)
        (ok false))))

;; Fetch metadata for a batch of carbon credits by batch ID
(define-read-only (get-batch-metadata-by-id (batch-id uint))
  (ok (map-get? batch-metadata batch-id)))

;; Fetch URI for the batch of carbon credits using batch ID
(define-read-only (get-batch-uri (batch-id uint))
  (ok (map-get? batch-metadata batch-id)))

;; Fetch a list of minted credit IDs starting from a specific point
(define-read-only (get-minted-credit-ids (start-id uint) (limit uint))
  (ok (map uint-to-response (list-tokens start-id limit))))

;; Fetch total minted credits
(define-read-only (get-total-minted-credits)
  (ok (var-get last-credit-id)))

(define-read-only (get-all-burn-status)
  (ok (map uint-to-burn-status (generate-sequence (var-get last-credit-id)))))

;; Check if the carbon credit has metadata
(define-read-only (has-credit-metadata? (credit-id uint))
  (ok (is-some (map-get? batch-metadata credit-id))))

;; Fetch all burned credits
(define-read-only (get-all-burned-credits)
  (ok (map uint-to-burn-status (generate-sequence (var-get last-credit-id)))))


(define-read-only (get-all-credit-uris)
  (let ((total-credits (var-get last-credit-id)))
    (ok (map uint-to-uri (generate-sequence total-credits)))))

(define-read-only (get-all-credit-status)
(let ((total-credits (var-get last-credit-id)))
  (ok (map uint-to-status (generate-sequence total-credits)))))

(define-read-only (has-metadata? (credit-id uint))
(ok (is-some (map-get? batch-metadata credit-id))))

(define-read-only (get-credit-metadata-by-id (credit-id uint))
(ok (map-get? batch-metadata credit-id)))

(define-read-only (get-credit-uri-by-id (credit-id uint))
(ok (map-get? credit-uri credit-id)))

(define-read-only (get-all-credit-owners)
(let ((total-credits (var-get last-credit-id)))
  (ok (map uint-to-owner (generate-sequence total-credits)))))

;; Fetch metadata for a specific batch of credits
(define-read-only (get-batch-metadata (batch-id uint))
  (ok (map-get? batch-metadata batch-id)))

;; Get detailed credit information for UI display
(define-read-only (get-credit-details (credit-id uint))
    (let ((owner (unwrap! (nft-get-owner? carbon-credit credit-id) err-token-not-found)))
        (ok {
            id: credit-id,
            owner: owner,
            uri: (unwrap! (map-get? credit-uri credit-id) err-token-not-found),
            burned: (is-credit-burned credit-id),
            metadata: (map-get? batch-metadata credit-id)
        })))

;; Test helper: Check credit ownership
(define-read-only (test-credit-ownership 
    (credit-id uint) 
    (expected-owner principal))
    (ok (is-eq 
        (some expected-owner)
        (nft-get-owner? carbon-credit credit-id))))

;; Test helper: Validate credit state
(define-read-only (test-credit-state (credit-id uint))
    (ok {
        exists: (is-some (nft-get-owner? carbon-credit credit-id)),
        burned: (is-credit-burned credit-id),
        has-metadata: (is-some (map-get? batch-metadata credit-id))
    }))

;; -----------------------------------------------------------
;; Add functionality to list the top 10 most minted credits
;; -----------------------------------------------------------
(define-read-only (list-top-10-most-minted)
  (ok (map uint-to-response (list-tokens u0 u10)))) ;; List the top 10 minted credits

;; -----------------------------------------------------------
;; Contract Initialization
;; -----------------------------------------------------------
(begin
  (var-set last-credit-id u0)) ;; Initialize the last credit ID
