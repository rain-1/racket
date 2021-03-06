#lang racket/base
(require (only-in '#%linklet primitive-table))

(provide atomically
         non-atomically
         atomically/no-interrupts/no-wind
         assert-atomic
         check-current-custodian)

(define table
  (or (primitive-table '#%thread)
      (error '#%thread "scheduler cooperation not supported by host")))

(define-syntax bounce
  (syntax-rules ()
    [(_ id)
     (begin
       (provide id)
       (define id (hash-ref table 'id)))]
    [(_ id ...)
     (begin (bounce id) ...)]))

(bounce make-semaphore
        semaphore-post
        semaphore-wait
        semaphore-peek-evt
        wrap-evt
        always-evt
        choice-evt ; raw variant that takes a list of evts
        sync
        sync/timeout
        evt?
        sync-atomic-poll-evt?
        prop:evt
        prop:secondary-evt
        poller
        poller-evt
        poll-ctx-poll?
        poll-ctx-select-proc
        poll-ctx-sched-info
        set-poll-ctx-incomplete?!
        schedule-info-did-work!
        control-state-evt
        async-evt
        schedule-info-current-exts
        current-sandman
        start-atomic
        end-atomic
        start-atomic/no-interrupts ; => disable GC, too, if GC can call back
        end-atomic/no-interrupts
        in-atomic-mode?
        current-custodian
        unsafe-custodian-register
        unsafe-custodian-unregister
        thread-push-kill-callback!
        thread-pop-kill-callback!
        set-get-subprocesses-time!)

(define-syntax-rule (atomically e ...)
  (begin
    (start-atomic)
    (begin0
      (let () e ...)
      (end-atomic))))

(define-syntax-rule (non-atomically e ...)
  (begin
    (end-atomic)
    (begin0
      (let () e ...)
      (start-atomic))))

;; Disables host interrupts, but the "no wind" part is
;; an unforced constraint: don't use anything related
;; to `dynamic-wind`, continuations, or continuation marks.
;; Cannot be exited with `non-atomically`.
(define-syntax-rule (atomically/no-interrupts/no-wind e ...)
  (begin
    (start-atomic/no-interrupts)
    (begin0
      (let () e ...)
      (end-atomic/no-interrupts))))

;; Enable for debugging
(define (assert-atomic)
  (void)
  #;
  (unless (in-atomic-mode?)
    (error 'assert-atomic "not in atomic mode")))

;; in atomic mode
(define (check-current-custodian who)
  (when (custodian-shut-down? (current-custodian))
    (end-atomic)
    (raise
     (exn:fail
      (string-append (symbol->string who) ": the current custodian has been shut down")
      (current-continuation-marks)))))
