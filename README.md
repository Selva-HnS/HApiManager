# HApiManager
[![Swift Version](https://img.shields.io/badge/swift-v6.0-orange.svg)](https://github.com/apple/swift)
[![Build Status](https://travis-ci.org/rauhul/api-manager.svg?branch=master)](https://github.com/Selva-HnS/HApiManager)

APIManager is a framework for abstracting RESTful API requests.

## Requirements
- Swift 6.0+

### Notes
- APIManager 0.0.1 is the last version that Swift 6 support

## Installation

### Swift Package Manager
The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler.

Once you have your Swift package set up, adding APIManager as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .Package(url: "https://github.com/Selva-HnS/HApiManager.git", from: "0.0.1")
]
```
## Usage
APIManager relies on users to create `MyAPIManager` types relevent to the RESTful APIs they are working with. `MyAPIManager` contain descriptions of various endpoints that return their responses as native swift objects.

### Making an MyAPIManager 

An MyAPIManager only needs to conform to one method  `request(endpoint: String,
        method: HTTPMethod = .get,
        soapMessage: String? = nil,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil,
        ssldomainkeys : [String: [String:[String]]]? = nil,
        timeIntervalRequest: Double = 30.0,
        timeIntervalResource: Double = 60.0,
        image: UIImage? = nil,
        fileurl: URL? = nil,
        successStatusCodes: [Int] = [200,201,202,203,204,205,206,207,208,209],
        completion: @escaping (Result<(Int, Data), Error>) -> Void)`. An example implementation can be found below:

```swift
    MyAPIManager.sharedInstance.request(endpoint: url, method: .put, parameters: nil, headers: nil, successStatusCodes: [200, 201]) { (result: Result<(Int, Data), Error>) in
            switch result {
                case .success(let result):
                case .failure(let error):
            }
    }
```

### Making an MyAPIManager
An MyAPIManager is made up of 11 components.

1. A `endpoint`. Endpoints in this service will be postpended to this URL segment. As a result a endpoint will generally look like the root URL of the API the service communicates with.

```swift
    endpoint: "https://api.example.com"
```

2. `method` to be sent alongside the `HTTPMethod`s made by the endpoints in your `MyAPIManager`.

```swift
    method: .post
```

3. `soapMessage` to be sent alongside the xml service `MyAPIManager`.

```swift
    soapMessage: """
                <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" 
                """
```

4. `parameters` to be sent alongside the `HTTPParameters`s made by the endpoints in your `MyAPIManager`.

```swift
    parameters: ["installation_id":"", "lsdt":""]
```

5. A set of RESTful api endpoints that you would like to use. These should be simple wrappers around the `MyAPIManager` constructor that can take in data (as `HTTPParameters` and/or `HTTPBody` as a json dictionary `[String: Any]`). For example if you would like to get user information by id, the endpoint may look like this:

```swift
    headers: ["Content-Type": "application/x-www-form-urlencoded"]
```

6. `ssldomainkeys` to be sent alongside the `SSLPinning` for secure `MyAPIManager`. Please import SSLPinningManager

```swift
    import SSLPinningManager

    ssldomainkeys: [
            "savwconnect.com": [SSLPingKeys:[
                "provide public key"
            ],SSLSubDomains:["provide domain name"]]
```

7. `timeIntervalRequest` to be sent alongside the time interval Request made by the endpoints in your `MyAPIManager`.

```swift
    timeIntervalRequest: 30.0
```

8. `timeIntervalResource` to be sent alongside the time interval Resource made by the endpoints in your `MyAPIManager`.

```swift
    timeIntervalResource: 30.0
```

9. `image` to be sent alongside share the image made by the endpoints in your `MyAPIManager`.

```swift
    image: UIImage
```

10. `fileurl` to be sent alongside share the file url made by the endpoints in your `MyAPIManager`.

```swift
    fileurl: URL
```

11. `successStatusCodes` to be sent alongside getting status code made by the endpoints in your `MyAPIManager`.

```swift
    successStatusCodes: [200, 201]
```

                
### Using an MyAPIManager
Now that you have an `MyAPIManager`, you can use it make RESTful API Requests.

All the RESTful API endpoints we need to access should already be defined in our `MyAPIManager`, so using them is simply a matter of calling them.

```swift
    MyAPIManager.sharedInstance.request(endpoint: "https://api.example.com", 
                                        method: .put, 
                                        parameters: nil, 
                                        headers: nil, 
                                        successStatusCodes: [200, 201]) { (result: Result<(Int, Data), Error>) in
            switch result {
                case .success(let result):
                    // Handle Success (Background thread)
                    DispatchQueue.main.async {
                        // Handle Success (main thread)
                    }
                case .failure(let error):
                    // Handle Failure (Background thread)
                    DispatchQueue.main.async {
                        // Handle Failure (main thread)
                    }
            }
    }
```


## Contributing
Please contribute using [Github Flow](https://guides.github.com/introduction/flow/). Create a branch, add commits, and [open a pull request](https://github.com/Selva-HnS/HApiManager/compare/).

## License
This project is licensed under the MIT License. For a full copy of this license take a look at the LICENSE file.
