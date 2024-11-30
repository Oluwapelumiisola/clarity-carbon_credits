;; -----------------------------------------------------------
;; Carbon Credit NFT Contract
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
