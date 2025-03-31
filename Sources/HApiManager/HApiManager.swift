// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Combine
import SSLPinningManager

public enum HTTPMethod: String {
    /// `CONNECT` method.
    case connect = "CONNECT"
    /// `DELETE` method.
    case delete = "DELETE"
    /// `GET` method.
    case get = "GET"
    /// `HEAD` method.
    case head = "HEAD"
    /// `OPTIONS` method.
    case options = "OPTIONS"
    /// `PATCH` method.
    case patch = "PATCH"
    /// `POST` method.
    case post = "POST"
    /// `PUT` method.
    case put = "PUT"
    /// `QUERY` method.
    case query = "QUERY"
    /// `TRACE` method.
    case trace = "TRACE"
}

@MainActor class SSLPinningDelegate: NSObject, URLSessionDelegate {
    nonisolated func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        SSLPinningController.shared.evaluateTrust(challenge: challenge, completion: { (status) in
            if status == false {
                completionHandler(.cancelAuthenticationChallenge, nil)
            } else {
                completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
            }
        })
    }
}

@MainActor open class MyAPIManager {
    static public let sharedInstance = MyAPIManager()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    //DataTaskPusblisher with return data
    
    public func request(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil,
        ssldomainkeys : [String: [String:[String]]]? = nil,
        token: String? = nil,
        completion: @escaping (Result<(Int, Data), Error>) -> Void)  {
            
            // Add Endpoint url
            guard let url = URL(string: endpoint) else {
                completion(.failure(URLError(.badURL)))
                return
            }
            
            // Define request
            var request = URLRequest(url: url)
            request.httpMethod = method.rawValue
            
            // Add Token
            if let token = token, token != "" {
                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            // Add Headers
            if headers != nil {
                headers?.forEach { key, value in
                    request.addValue(value, forHTTPHeaderField: key)
                }
            } else {
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            
            // Add Parameters (Query for GET, Body for others)
            if let parameters = parameters {
                if method == .get {
                    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
                    request.url = components?.url
                } else {
                    request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
                }
            }
            
            // 1. Create 'dataTaskPusblisher'(Publisher) to make the API call with ssl keys
            let urlSession: URLSession = {
                let serverConfig = ssldomainkeys ?? [:]
                SSLPinningController.shared.setCofiGuration(configuration: serverConfig)
                
                let configuration = URLSessionConfiguration.default
                configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
                let cache = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil) // No cache
                configuration.urlCache = cache
                configuration.requestCachePolicy = .reloadIgnoringLocalCacheData // Disable cache
                configuration.connectionProxyDictionary = nil
                
                return URLSession(configuration: configuration, delegate: SSLPinningDelegate(), delegateQueue: OperationQueue())
            }()
            
            urlSession.dataTaskPublisher(for: request)
            //URLSession.shared.dataTaskPublisher(for: request)
            
            // 2. Make this process in main thread. (you can do this in background thread as well)
                .receive(on: DispatchQueue.main)

            // 3. Use 'tryMap'(Operator) to get the data from the result
                .tryMap({ (data, response) -> (Int, Data) in
                    guard let response = response as? HTTPURLResponse,
                          response.statusCode >= 200 else {
                        throw URLError(.badServerResponse)
                    }
                    return (response.statusCode, data)
                })
            
            //.map { $0.data }
            // 4. Decode the data into the 'Decodable' struct using JSONDecoder
            //.decode(type: T.self, decoder: JSONDecoder())
            // 5. Use 'sink'(Subcriber) to get the decoaded value or error, and pass it to completion handler
                .sink { (resultCompletion) in
                    switch resultCompletion {
                    case .failure(let error):
                        completion(.failure(error))
                    case .finished:
                        return
                    }
                } receiveValue: { (resultArr) in
                    completion(.success((resultArr.0, resultArr.1)))
                }
            // 6. saving the subscriber into an AnyCancellable Set (without this step this won't work)
                .store(in: &cancellables)
        }

    //FuturePublisher with return T
    
    public func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil,
        ssldomainkeys : [String: [String:[String]]]? = nil,
        token: String? = nil,
        completion: @escaping (Result<T, Error>) -> Void) {
            
            // Add Endpoint url
            guard let url = URL(string: endpoint) else {
                completion(.failure(URLError(.badURL)))
                return
            }
            
            // Define request
            var request = URLRequest(url: url)
            request.httpMethod = method.rawValue
            
            // Add Token
            if let token = token, token != "" {
                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            // Add Headers
            if headers != nil {
                headers?.forEach { key, value in
                    request.addValue(value, forHTTPHeaderField: key)
                }
            } else {
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            
            // Add Parameters (Query for GET, Body for others)
            if let parameters = parameters {
                if method == .get {
                    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
                    request.url = components?.url
                } else {
                    request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
                }
            }
            
            // 1. Create 'dataTaskPusblisher'(Publisher) to make the API call with ssl keys
            let urlSession: URLSession = {
                let serverConfig = ssldomainkeys ?? [:]
                SSLPinningController.shared.setCofiGuration(configuration: serverConfig)
                
                let configuration = URLSessionConfiguration.default
                configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
                let cache = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil) // No cache
                configuration.urlCache = cache
                configuration.requestCachePolicy = .reloadIgnoringLocalCacheData // Disable cache
                configuration.connectionProxyDictionary = nil
                
                return URLSession(configuration: configuration, delegate: SSLPinningDelegate(), delegateQueue: OperationQueue())
            }()
            
            urlSession.dataTaskPublisher(for: request)
            //URLSession.shared.dataTaskPublisher(for: request)
            
            // 2. Make this process in main thread. (you can do this in background thread as well)
                .receive(on: DispatchQueue.main)
            
            // 3. Use 'map'(Operator) to get the data from the result
                .map { $0.data }
            // 4. Decode the data into the 'Decodable' struct using JSONDecoder
                .decode(type: T.self, decoder: JSONDecoder())
            
            // 5. Use 'sink'(Subcriber) to get the decoaded value or error, and pass it to completion handler
                .sink { (resultCompletion) in
                    switch resultCompletion {
                    case .failure(let error):
                        completion(.failure(error))
                    case .finished:
                        return
                    }
                } receiveValue: { (resultArr) in
                    completion(.success((resultArr)))
                }
            // 6. saving the subscriber into an AnyCancellable Set (without this step this won't work)
                .store(in: &cancellables)
        }
    

    
}
