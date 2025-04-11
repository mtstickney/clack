(in-package :cl-user)
(defpackage clack.handler
  (:use :cl)
  (:import-from :clack.util
                :find-handler)
  (:import-from :bordeaux-threads
                :threadp
                :make-thread
                :thread-alive-p
                :destroy-thread)
  (:import-from :usocket)
  (:export :run
           :stop))
(in-package :clack.handler)

(defstruct handler
  server
  acceptor)

(defun run (app server &rest args &key (address nil address-specified-p) use-thread debug &allow-other-keys)
  (let ((handler-package (find-handler server))
        (bt2:*default-special-bindings* `((*standard-output* . ,*standard-output*)
                                          (*error-output* . ,*error-output*)
                                          ,@bt2:*default-special-bindings*)))
    (when debug
      (format t "NOTICE: Running in debug mode. Debugger will be invoked on errors.
  Specify ':debug nil' to turn it off on remote environments."))
    (flet ((run-server ()
             (apply (intern #.(string '#:run) handler-package)
                    app
                    :allow-other-keys t
                    (append
                      (and address-specified-p
                           (list :address
                                 (usocket:host-to-hostname
                                   (usocket:get-host-by-name address))))
                      args))))
      (make-handler
        :server server
        :acceptor (if use-thread
                      (bt2:make-thread #'run-server
                                       :name (format nil "clack-handler-~(~A~)" server)
                                       :initial-bindings
                                       `((bt2:*default-special-bindings* . ',bt2:*default-special-bindings*)
                                         ,@bt2:*default-special-bindings*))
                      (run-server))))))

(defun stop (handler)
  (let ((acceptor (handler-acceptor handler)))
    (if (bt2:threadp acceptor)
        (progn
          (when (bt2:thread-alive-p acceptor)
            (bt2:destroy-thread acceptor))
          (sleep 0.5))
        (let ((package (find-handler (handler-server handler))))
          (funcall (intern #.(string '#:stop) package) acceptor)))
    t))
