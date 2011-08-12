#|
  This file is a part of Caveman package.
  URL: http://github.com/fukamachi/caveman
  Copyright (c) 2011 Eitarow Fukamachi <e.arrows@gmail.com>

  Caveman is freely distributable under the LLGPL License.
|#

(clack.util:namespace caveman.project
  (:use :cl
        :anaphora
        :clack
        :clack.builder
        :clack.middleware.static
        :clack.middleware.session
        :caveman.middleware.context)
  (:shadow :stop)
  (:import-from :local-time
                :format-timestring
                :now)
  (:import-from :cl-syntax
                :use-syntax)
  (:import-from :cl-syntax-annot
                :annot-syntax)
  (:import-from :cl-ppcre
                :scan
                :scan-to-strings)
  (:import-from :cl-fad
                :file-exists-p)
  (:import-from :caveman.context
                :*project*)
  (:export :debug-mode-p
           :project-mode
           :config))

(use-syntax annot-syntax)

@export
(defclass <project> (<component>)
     ((config :initarg :config :initform nil
              :accessor config)
      (acceptor :initform nil :accessor acceptor)
      (debug-mode-p :type boolean
                    :initarg :debug-mode-p
                    :initform t
                    :accessor debug-mode-p)
      (mode :type keyword
            :initarg :mode
            :accessor project-mode)))

@export
(defmethod build ((this <project>) &optional app)
  (builder
   (clack.middleware.logger:<clack-middleware-logger>
    :logger (make-instance 'clack.logger.file:<clack-logger-file>
               :output-file
               (merge-pathnames
                (local-time:format-timestring nil
                 (local-time:now)
                 :format
                 '("log-" (:year 4) (:month 2) (:day 2)))
                (merge-pathnames
                 (getf (config this) :log-path)
                 (getf (config this) :application-root)))))
   (<clack-middleware-static>
    :path (lambda (path)
            (when (ppcre:scan "^(?:/static/|/robot\\.txt$|/favicon.ico$)" path)
              path))
    :root (merge-pathnames (getf (config this) :static-path)
                           (getf (config this) :application-root)))
   <clack-middleware-session>
   <caveman-middleware-context>
   app))

(defun slurp-file (path)
  "Read a specified file and return the content as a sequence."
  (with-open-file (stream path :direction :input)
    (let ((seq (make-array (file-length stream) :element-type 'character :fill-pointer t)))
      (setf (fill-pointer seq) (read-sequence seq stream))
      seq)))

@export
(defmethod initialize ((this <project>)))

@export
(defmethod load-config ((this <project>) mode)
  (let ((config-file (asdf:system-relative-pathname
                      (intern
                       (package-name (symbol-package (type-of this)))
                       :keyword)
                      (format nil "config/~(~A~).lisp" mode))))
    (when (file-exists-p config-file)
      (eval
       (read-from-string
        (slurp-file config-file))))))

@export
(defmethod start ((this <project>) &key (mode :dev) port server debug lazy)
  (let ((*project* this)
        (config (load-config this mode)))
    (setf (config this) config)
    (ensure-directories-exist
     (merge-pathnames (getf config :log-path)
                      (getf config :application-root)))
    (setf (project-mode this) mode)
    (setf (debug-mode-p this) debug)
    (setf *builder-lazy-p* lazy)
    (initialize this)
    (let ((app (build this)))
      (setf (acceptor this)
            (clackup
             (lambda (env) (let ((*project* this)) (call app env)))
             :port (or port (getf config :port))
             :debug debug
             :server (or server (getf config :server)))))))

@export
(defmethod stop ((this <project>))
  "Stop a server."
  (swhen (acceptor this)
    (clack:stop it)
    (setf it nil)))

(doc:start)

@doc:NAME "
Caveman.Project - Caveman Project Class.
"

@doc:SYNOPSIS "
    ;; Usually you shouldn't write this code.
    ;; These code will be generated by `caveman.skeleton:generate'.
    (defclass <myapp> (<project>) ())
    (defmethod build ((this <myapp>) &optional app)
      (builder ...))
    (defmethod load-config ((this <myapp) mode)
      ;; override if you want.
      )
"

@doc:DESCRIPTION "
Caveman.Project provides a base class `<project>' for Caveman Project. Project manages how to build applications and middlewares and loads configuration.

Usually you don't have to cave about this package because `caveman.skeleton:generate' will generate code for you.
"

@doc:AUTHOR "
* Eitarow Fukamachi (e.arrows@gmail.com)
"

@doc:SEE "
* Clack.Builder
"