import Foundation

func printUsage() {
    print("USAGE: \(CommandLine.arguments[0]) [commands]")
    print("Commands Description")
    print("  -v     version")
    print("  -f     Search. Requires a query string as the second argument.")
    print("  -e     Edit. Requires --account STRING --service STRING [--agroup STRING] --data STRING")
    print("  -d     Delete. Requires --account STRING --service STRING [--agroup STRING]")
    print("NOTES:")
    print(" * Account and Service names are used to uniquely identify a item. An optional AccessGroup can also be passed to identify the item.")
    print(" * If there is no Account name pass an empty string.")
    print(" * Search is from the following group {Account, Service, AccessGroup, Protection} and is case in-sensitive.")
    print("EXAMPLES:")
    print(" * To Dump entire keychain: $ keychaineditor")
    print(" * Limit dump by searching: $ keychaineditor -f 'test'")
    print(" * Edit a keychain item:    $ keychaineditor -e --account 'TestAccount' --service 'TestService' --data 'TestData'")
    print(" * Delete a keychain item:  $ keychaineditor -d --account 'TestAccount' --service 'TestService'")
    exit(EXIT_FAILURE)
}

func handleSearch(args: UserDefaults) {
    if let query = args.string(forKey: "f") {
        let items = search(for: query, in: dumpKeychainItems())
        print(convertToJSON(for: items))
    } else {
        printUsage()
    }
}

func handleEdit(args: UserDefaults) {
    if let account = args.string(forKey: "-account") , let service = args.string(forKey: "-service") , let data = args.string(forKey: "-data") {
        let status = updateKeychainItem(account: account, service: service, data: decodeIfBase64(for: data), agroup: args.string(forKey: "-agroup"))
        print(errorMessage(for: status))
    } else {
        printUsage()
    }
}

func handleDelete(args: UserDefaults) {
    if let account = args.string(forKey: "-account") , let service = args.string(forKey: "-service") {
        let status = deleteKeychainItem(account: account, service: service, agroup: args.string(forKey: "-agroup"))
        print(errorMessage(for: status))
    } else {
        printUsage()
    }
}

/*
  Start of Program.
*/

guard CommandLine.arguments.count >= 2 else {
    print(convertToJSON(for: dumpKeychainItems()))
    exit(EXIT_SUCCESS)
}

switch CommandLine.arguments[1] {
case "-v": print("KeychainEditor Version = 2.1")
case "-f": handleSearch(args: UserDefaults.standard)
case "-e": handleEdit(args: UserDefaults.standard)
case "-d": handleDelete(args: UserDefaults.standard)
case "-h": printUsage()
default: printUsage()
}
