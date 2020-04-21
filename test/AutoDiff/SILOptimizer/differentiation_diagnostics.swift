// RUN: %target-swift-frontend -emit-sil -verify %s

// Test differentiation transform diagnostics.

import _Differentiation

//===----------------------------------------------------------------------===//
// Basic function
//===----------------------------------------------------------------------===//

@differentiable
func basic(_ x: Float) -> Float {
  return x
}

//===----------------------------------------------------------------------===//
// Control flow
//===----------------------------------------------------------------------===//

@differentiable
func conditional(_ x: Float, _ flag: Bool) -> Float {
  let y: Float
  if flag {
    y = x
  } else {
    y = x
  }
  return y
}

// TF-433: Test `try_apply` differentiation.

func throwing() throws -> Void {}

// expected-error @+2 {{function is not differentiable}}
// expected-note @+2 {{when differentiating this function definition}}
@differentiable
func try_apply(_ x: Float) -> Float {
  // expected-note @+1 {{cannot differentiate unsupported control flow}}
  try! throwing()
  return x
}

func rethrowing(_ x: () throws -> Void) rethrows -> Void {}

// expected-error @+2 {{function is not differentiable}}
// expected-note @+2 {{when differentiating this function definition}}
@differentiable
func try_apply_rethrows(_ x: Float) -> Float {
  // expected-note @+1 {{cannot differentiate unsupported control flow}}
  rethrowing({})
  return x
}

//===----------------------------------------------------------------------===//
// Unreachable
//===----------------------------------------------------------------------===//

// expected-error @+2 {{function is not differentiable}}
// expected-note @+2 {{when differentiating this function definition}}
@differentiable
func noReturn(_ x: Float) -> Float {
  let _ = x
  // expected-error @+2 {{missing return in a function expected to return 'Float'}}
  // expected-note @+1 {{missing return for differentiation}}
}

//===----------------------------------------------------------------------===//
// Conversion to `@differentiable(linear)` (not yet supported)
//===----------------------------------------------------------------------===//

// expected-error @+1 {{conversion to '@differentiable(linear)' function type is not yet supported}}
let _: @differentiable(linear) (Float) -> Float = { x in x }

//===----------------------------------------------------------------------===//
// Property wrappers
//===----------------------------------------------------------------------===//

@propertyWrapper
struct Wrapper<Value> {
  var wrappedValue: Value
  var projectedValue: Self { self }
}

@propertyWrapper
struct DifferentiableWrapper<Value> {
  var wrappedValue: Value
  var projectedValue: Self { self }
}
extension DifferentiableWrapper: Differentiable where Value: Differentiable {}
// Note: property wrapped value differentiation works even if wrapper types do
// not conform to `Differentiable`. The conformance here tests projected value
// accesses.

struct Struct: Differentiable {
  // expected-error @+2 {{expression is not differentiable}}
  // expected-note @+1 {{property cannot be differentiated because 'Struct.TangentVector' does not have a member named '_x'}}
  @DifferentiableWrapper @DifferentiableWrapper var x: Float = 10

  @Wrapper var y: Float = 20
  var z: Float = 30
}

@differentiable
func differentiableProjectedValueAccess(_ s: Struct) -> Float {
  s.$x.wrappedValue.wrappedValue
}

// expected-error @+2 {{function is not differentiable}}
// expected-note @+2 {{when differentiating this function definition}}
@differentiable
func projectedValueAccess(_ s: Struct) -> Float {
  // expected-note @+1 {{cannot differentiate through a non-differentiable result; do you want to use 'withoutDerivative(at:)'?}}
  s.$y.wrappedValue
}

// SR-12640: Test `wrapperValue.modify` differentiation.

// expected-error @+2 {{function is not differentiable}}
// expected-note @+2 {{when differentiating this function definition}}
@differentiable
func modify(_ s: Struct, _ x: Float) -> Float {
  var s = s
  // expected-note @+1 {{differentiation of coroutine calls is not yet supported}}
  s.x *= x * s.z
  return s.x
}
