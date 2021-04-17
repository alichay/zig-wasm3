;; This file is grabbed from Wasmer's examples.
;; https://github.com/wasmerio/wasmer/blob/1b0c87034708e22adbfdd3725b25bf1810a21479/examples/exports_global.rs#L26-L33
;; Wasmer is licensed under the MIT license at the time that this example was retrieved.
;; https://github.com/wasmerio/wasmer/blob/1b0c87034708e22adbfdd3725b25bf1810a21479/LICENSE

(module
  (global $one (export "one") f32 (f32.const 1))
  (global $some (export "some") (mut f32) (f32.const 0))
  (func (export "get_one") (result f32) (global.get $one))
  (func (export "get_some") (result f32) (global.get $some))
  (func (export "set_some") (param f32) (global.set $some (local.get 0))))
