;; Parametric Insurance Smart Contract
;; Process weather data triggers and execute automatic insurance payouts

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INSUFFICIENT-PREMIUM (err u103))
(define-constant ERR-POLICY-EXPIRED (err u104))
(define-constant ERR-TRIGGER-NOT-MET (err u105))
(define-constant ERR-ALREADY-PAID (err u106))
(define-constant ERR-NOT-AUTHORIZED (err u107))

;; Policy Status Constants
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-EXPIRED u2)
(define-constant STATUS-CLAIMED u3)
(define-constant STATUS-CANCELLED u4)

;; Disaster Type Constants
(define-constant DISASTER-FLOOD u1)
(define-constant DISASTER-DROUGHT u2)
(define-constant DISASTER-HURRICANE u3)
(define-constant DISASTER-EARTHQUAKE u4)

;; Data Variables
(define-data-var policy-counter uint u0)
(define-data-var claim-counter uint u0)
(define-data-var total-pool uint u0)

;; Data Maps
(define-map policies
    { policy-id: uint }
    {
        holder: principal,
        disaster-type: uint,
        coverage-amount: uint,
        premium-paid: uint,
        start-date: uint,
        end-date: uint,
        location: (string-ascii 64),
        trigger-value: uint,
        status: uint
    }
)

(define-map weather-data
    { location: (string-ascii 64), date: uint }
    {
        rainfall-mm: uint,
        wind-speed-kmh: uint,
        temperature-c: uint,
        humidity-percent: uint,
        data-source: principal,
        verified: bool
    }
)

(define-map claims
    { claim-id: uint }
    {
        policy-id: uint,
        trigger-value: uint,
        actual-value: uint,
        payout-amount: uint,
        claim-date: uint,
        processed: bool
    }
)

(define-map authorized-oracles principal bool)

;; Authorization functions
(define-public (add-oracle (oracle principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (ok (map-set authorized-oracles oracle true))
    )
)

;; Helper functions
(define-read-only (is-authorized-oracle (oracle principal))
    (default-to false (map-get? authorized-oracles oracle))
)

(define-private (increment-policy-counter)
    (let ((current (var-get policy-counter)))
        (var-set policy-counter (+ current u1))
        (+ current u1)
    )
)

(define-private (increment-claim-counter)
    (let ((current (var-get claim-counter)))
        (var-set claim-counter (+ current u1))
        (+ current u1)
    )
)

;; Policy Management
(define-public (create-policy
    (disaster-type uint)
    (coverage-amount uint)
    (duration-days uint)
    (location (string-ascii 64))
    (trigger-value uint))
    (let (
        (policy-id (increment-policy-counter))
        (premium (calculate-premium disaster-type coverage-amount duration-days))
        (end-date (+ stacks-block-height duration-days))
    )
        (asserts! (>= (stx-get-balance tx-sender) premium) ERR-INSUFFICIENT-PREMIUM)
        (asserts! (<= disaster-type DISASTER-EARTHQUAKE) ERR-NOT-FOUND)
        
        ;; Transfer premium to contract (simplified)
        (var-set total-pool (+ (var-get total-pool) premium))
        
        (map-set policies
            { policy-id: policy-id }
            {
                holder: tx-sender,
                disaster-type: disaster-type,
                coverage-amount: coverage-amount,
                premium-paid: premium,
                start-date: stacks-block-height,
                end-date: end-date,
                location: location,
                trigger-value: trigger-value,
                status: STATUS-ACTIVE
            }
        )
        (ok policy-id)
    )
)

;; Premium calculation (simplified)
(define-private (calculate-premium (disaster-type uint) (coverage-amount uint) (duration-days uint))
    (let (
        (base-rate (if (is-eq disaster-type DISASTER-FLOOD)
            u10
            (if (is-eq disaster-type DISASTER-DROUGHT)
                u15
                u20
            )
        ))
        (risk-factor (/ coverage-amount u1000))
        (duration-factor (/ duration-days u30))
    )
        (* base-rate (* risk-factor duration-factor))
    )
)

;; Weather Data Submission
(define-public (submit-weather-data
    (location (string-ascii 64))
    (date uint)
    (rainfall-mm uint)
    (wind-speed-kmh uint)
    (temperature-c uint)
    (humidity-percent uint))
    (begin
        (asserts! (is-authorized-oracle tx-sender) ERR-NOT-AUTHORIZED)
        
        (map-set weather-data
            { location: location, date: date }
            {
                rainfall-mm: rainfall-mm,
                wind-speed-kmh: wind-speed-kmh,
                temperature-c: temperature-c,
                humidity-percent: humidity-percent,
                data-source: tx-sender,
                verified: true
            }
        )
        (ok true)
    )
)

;; Claim Processing
(define-public (process-claim (policy-id uint))
    (let (
        (policy (unwrap! (map-get? policies { policy-id: policy-id }) ERR-NOT-FOUND))
        (location (get location policy))
        (disaster-type (get disaster-type policy))
        (trigger-value (get trigger-value policy))
    )
        (asserts! (is-eq (get status policy) STATUS-ACTIVE) ERR-POLICY-EXPIRED)
        (asserts! (< stacks-block-height (get end-date policy)) ERR-POLICY-EXPIRED)
        
        ;; Get weather data for location
        (let (
            (weather (unwrap! (map-get? weather-data { location: location, date: stacks-block-height }) ERR-NOT-FOUND))
            (actual-value (get-disaster-value disaster-type weather))
            (trigger-met (check-trigger disaster-type trigger-value actual-value))
        )
            (if trigger-met
                (let (
                    (claim-id (increment-claim-counter))
                    (payout-amount (get coverage-amount policy))
                )
                    (map-set claims
                        { claim-id: claim-id }
                        {
                            policy-id: policy-id,
                            trigger-value: trigger-value,
                            actual-value: actual-value,
                            payout-amount: payout-amount,
                            claim-date: stacks-block-height,
                            processed: true
                        }
                    )
                    
                    (map-set policies
                        { policy-id: policy-id }
                        (merge policy { status: STATUS-CLAIMED })
                    )
                    
                    ;; Execute payout (simplified)
                    (var-set total-pool (- (var-get total-pool) payout-amount))
                    (ok claim-id)
                )
                ERR-TRIGGER-NOT-MET
            )
        )
    )
)

;; Helper function to get disaster-specific value from weather data
(define-private (get-disaster-value (disaster-type uint) (weather {rainfall-mm: uint, wind-speed-kmh: uint, temperature-c: uint, humidity-percent: uint, data-source: principal, verified: bool}))
    (if (is-eq disaster-type DISASTER-FLOOD)
        (get rainfall-mm weather)
        (if (is-eq disaster-type DISASTER-DROUGHT)
            (get rainfall-mm weather)
            (if (is-eq disaster-type DISASTER-HURRICANE)
                (get wind-speed-kmh weather)
                (get temperature-c weather)
            )
        )
    )
)

;; Check if trigger condition is met
(define-private (check-trigger (disaster-type uint) (trigger-value uint) (actual-value uint))
    (if (or (is-eq disaster-type DISASTER-FLOOD) (is-eq disaster-type DISASTER-HURRICANE))
        (>= actual-value trigger-value)  ;; Trigger when value exceeds threshold
        (<= actual-value trigger-value)  ;; Trigger when value is below threshold (drought)
    )
)

;; Read-only functions
(define-read-only (get-policy (policy-id uint))
    (map-get? policies { policy-id: policy-id })
)

(define-read-only (get-weather-data (location (string-ascii 64)) (date uint))
    (map-get? weather-data { location: location, date: date })
)

(define-read-only (get-claim (claim-id uint))
    (map-get? claims { claim-id: claim-id })
)

(define-read-only (get-policy-count)
    (var-get policy-counter)
)

(define-read-only (get-total-pool)
    (var-get total-pool)
)

(define-read-only (check-payout-eligibility (policy-id uint) (location (string-ascii 64)))
    (let (
        (policy (unwrap! (map-get? policies { policy-id: policy-id }) ERR-NOT-FOUND))
        (weather (map-get? weather-data { location: location, date: stacks-block-height }))
    )
        (match weather
            weather-record
                (let (
                    (disaster-type (get disaster-type policy))
                    (trigger-value (get trigger-value policy))
                    (actual-value (get-disaster-value disaster-type weather-record))
                )
                    (ok (check-trigger disaster-type trigger-value actual-value))
                )
            (ok false)
        )
    )
)

;; title: parametric-insurance
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

