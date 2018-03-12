# Changelog

This file contains all of the (intentional) changes in behaviour that this
version of Pascal-FC has over the last official version.

## 2018-03-12

### Interpreter

- Made `read` skip newlines and tabs when reading numbers (previously the
  interpreter would abnormal-halt instead): this is closer to eg. Free Pascal.
  - Some bugs may have been introduced.

## Earlier

These changes predate the changelog.

### Compiler

- Overhauled internal treatment of keywords; this doesn't add any new
  functionality itself, but paves the way for increased identifier name limits.
  - As of writing, there are a few keyword bugs left to fix.
- Removed internal line length limit: lines may now be up to 255 characters
  long in theory.
  - Not yet tested in practice.
