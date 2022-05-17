## Unreleased

- Widget builder: ignore `null` values when `nullValueBuilder` is unset.

## 0.3.0

- Widget builder: forward stream errors to the default handler when no `onError`
  callback is specified.
- Widget builder: correctly rebuild, and update state and configuration on
  widget updates.
- Widget builder: *breaking*: take non-nullable type `T` as a generic argument,
  and provide explicit guarantees on `builder()` parameter type.

## 0.2.0+1

- Change package description to fit within pub.dev guidelines.

## 0.2.0

- Expand on description of the package as recommended by pub.dev.
- Remove binding to a specific version of `test` package.
- Update README with details and little snippets.
- Add more documentation in the code.
- Implement `valueOrNull` extension (#2).
- Fix example and add tests.

## 0.1.1

- Improvements on null-safety implementation. Support `null` as an
  initial value.

## 0.1.0

- Add example on how to use package.
- Update README with info oh how to use the package.

## 0.0.2

- Migrate to null-safety.

## 0.0.1

- Initial version.
