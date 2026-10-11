#!/usr/bin/env python3
"""Run PlayerCore assertions on Macs with Command Line Tools but no XCTest."""
import pathlib
import re
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]
work = pathlib.Path(tempfile.mkdtemp(prefix='axontube-core-check-'))
sources = [(path.stem, path.read_text().replace('import XCTest\n', '').replace('@testable import PlayerCore\n', '')) for path in sorted((root/'Tests/PlayerCoreTests').glob('*Tests.swift'))]
assertions = r'''
var failures = 0
class XCTestCase {}
struct CheckError: Error {}
func report(_ message: String, _ file: StaticString, _ line: UInt) { failures += 1; print("FAIL \(file):\(line): \(message)") }
func XCTAssertEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
    do { let x = try a(); let y = try b(); if x != y { report("\(x) != \(y) \(message)", file, line) } } catch { report("\(error)", file, line) }
}
func XCTAssertTrue(_ value: @autoclosure () -> Bool, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) { if !value() { report(message, file, line) } }
func XCTAssertNil<T>(_ value: @autoclosure () -> T?, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) { if value() != nil { report(message, file, line) } }
func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, _ message: String = "", file: StaticString = #filePath, line: UInt = #line, _ handler: (Error) -> Void = { _ in }) {
    do { _ = try expression(); report("Expected error \(message)", file, line) } catch { handler(error) }
}
func XCTUnwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) throws -> T {
    guard let value else { report("Expected nonnil", file, line); throw CheckError() }; return value
}
'''
main = ['import Foundation']
count = 0
for class_name, source in sources:
    tests = re.findall(r'func (test\w+)\(\)( throws)?', source)
    count += len(tests)
    main.append(f'let checks{class_name} = {class_name}()')
    for name, throwing in tests:
        if throwing:
            main.append(f'do {{ try checks{class_name}.{name}(); print("CHECK {name}") }} catch {{ failures += 1; print("FAIL {name}: \\(error)") }}')
        else:
            main.append(f'checks{class_name}.{name}(); print("CHECK {name}")')
main += [f'print("{count} checks; \\(failures) failures")', 'exit(failures == 0 ? 0 : 1)']
(work/'Assertions.swift').write_text('import Foundation\n' + assertions)
(work/'Tests.swift').write_text('\n\n'.join(source for _, source in sources))
(work/'main.swift').write_text('\n'.join(main))
core_sources = [str(path) for path in sorted((root/'Sources/PlayerCore').glob('*.swift'))]
subprocess.run(['xcrun','swiftc',*core_sources,str(work/'Assertions.swift'),str(work/'Tests.swift'),str(work/'main.swift'),'-o',str(work/'checks')], check=True)
subprocess.run([str(work/'checks')], check=True)
