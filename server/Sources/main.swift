import Foundation
import libfcgi

func main() {
  var count = 1

  var r = libfcgi.FCGI_Accept()
  while(r >= 0) {
    libfcgi.FCGI_puts("Content-type: text/html\r\n")
    libfcgi.FCGI_puts("\r\n")
    libfcgi.FCGI_puts("Hello world!<br>\r\n")
    let keys = ProcessInfo.processInfo.environment.keys.joined(separator: " ")
    libfcgi.FCGI_puts("\(keys)\n")
    
    let scriptName = ProcessInfo.processInfo.environment["SCRIPT_NAME"]!
    libfcgi.FCGI_puts("\(scriptName)\n")
    libfcgi.FCGI_puts("Request number \(count)")
    count += 1
    
    r = libfcgi.FCGI_Accept()
  }
}

main()

