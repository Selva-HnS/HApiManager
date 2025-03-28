// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Combine
import SSLPinningManager

enum HTTPMethod: String {
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

@MainActor class MyAPIManager {
    static let sharedInstance = MyAPIManager()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    //FuturePublisher with return data
    func request(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil,
        ssldomainkeys : [String: [String:[String]]]? = nil,
        token: String? = nil
    ) -> Future<(Int, Data), Error> {
        return Future { promise in
            guard let url = URL(string: endpoint) else {
                return promise(.failure(URLError(.badURL)))
            }
            
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

            //URLSession.shared.dataTask(with: request) { data, response, error in
            urlSession.dataTask(with: request) { data, response, error in
                Task { @MainActor in
                    if let error = error {
                        return promise(.failure(error))
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        return promise(.failure(URLError(.badServerResponse)))
                    }
                    
                    guard let data = data else {
                        return promise(.failure(URLError(.badServerResponse)))
                    }
                    
                    promise(.success((httpResponse.statusCode, data)))
                }
            }.resume()
        }
    }
    
    //FuturePublisher with return T
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil,
        ssldomainkeys : [String: [String:[String]]]? = nil,
        token: String? = nil,
        responseType: T.Type
    ) -> Future<(Int, T), Error> {
        return Future { promise in
            guard let url = URL(string: endpoint) else {
                return promise(.failure(URLError(.badURL)))
            }
            
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

            //URLSession.shared.dataTask(with: request) { data, response, error in
            urlSession.dataTask(with: request) { data, response, error in
                Task { @MainActor in
                    if let error = error {
                        return promise(.failure(error))
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        return promise(.failure(URLError(.badServerResponse)))
                    }
                    
                    guard let data = data else {
                        return promise(.failure(URLError(.badServerResponse)))
                    }
                    
                    do {
                        let decodedData = try JSONDecoder().decode(T.self, from: data)
                        promise(.success((httpResponse.statusCode, decodedData)))
                    } catch {
                        promise(.failure(error))
                    }
                }
            }.resume()
        }
    }
    
}
