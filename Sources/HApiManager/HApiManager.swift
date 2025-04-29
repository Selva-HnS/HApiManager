// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Combine
import SSLPinningManager
import UIKit
import UniformTypeIdentifiers

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

public enum APIError: LocalizedError {
    case invalidResponse(statusCode: Int)
    case decodingError
    case unknownError

    public var errorDescription: String? {
        switch self {
        case .invalidResponse(let statusCode):
            return "Request failed with status code: \(statusCode)"
        case .decodingError:
            return "Failed to decode the response."
        case .unknownError:
            return "An unknown error occurred."
        }
    }
    
    public var responseCode: Int? {
        switch self {
        case .invalidResponse(let statusCode):
            return statusCode
        case .decodingError:
            return 0
        case .unknownError:
            return 520
        }
    }
}

struct Media {
    let key: String
    let filename: String
    let data: Data
    let mimeType: String
    init?(withImage image: UIImage, forKey key: String) {
        self.key = key
        self.mimeType = "image/png"//"image/jpeg"
        self.filename = "imagefile.png"//"imagefile.jpg"
        guard let data = image.jpegData(compressionQuality: 0.7) else { return nil }
        self.data = data
    }
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
        soapMessage: String? = nil,
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil,
        ssldomainkeys : [String: [String:[String]]]? = nil,
        timeIntervalRequest: Double = 30.0,
        timeIntervalResource: Double = 60.0,
        image: UIImage? = nil,
        fileurl: URL? = nil,
        successStatusCodes: [Int] = [200,201,202,203,204,205,206,207,208,209],
        completion: @escaping (Result<(Int, Data), Error>) -> Void)  {
            
            // Add Endpoint url
            guard let url = URL(string: endpoint) else {
                completion(.failure(URLError(.badURL)))
                return
            }
            
            // Define request
            var request = URLRequest(url: url)
            request.httpMethod = method.rawValue
                        
            // Add Headers
            var isdefault: Bool = false
            var urlencoded : Bool = false
            let boundary = "Boundary-\(UUID().uuidString)"

            if headers != nil {
                headers?.forEach { key, value in
                    if (image != nil || fileurl != nil) {
                        if !(value.contains("multipart/form-data; boundary=")) {
                            request.addValue(value, forHTTPHeaderField: key)
                        }
                    } else {
                        if value.contains("application/json") {
                            isdefault = true
                        }
                        if value.contains("x-www-form-urlencoded") {
                            urlencoded = true
                        }
                        request.addValue(value, forHTTPHeaderField: key)
                    }
                }
            } else {
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            
            // Add Soap Message
            if let soaptxt = soapMessage, soaptxt != "" {
                request.httpBody = soaptxt.data(using: .utf8)!
            }

            
            // Add multipart/form-data
            if (image != nil || fileurl != nil) {
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            } else {
                // Add default Content-Type
                if !isdefault {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            }

            // Add Image
            if let img = image, image != nil {
                let convertedImage = img.resized(toWidth: 1024.0) ?? UIImage()
                let mediaImage = Media(withImage: convertedImage, forKey: "file")
                
                // Create multipart body
                let dataBody = createDataBody(withParameters: nil, media: [mediaImage!], boundary: boundary)
                request.httpBody = dataBody
            }
            
            // Add File such as pdf, xlsx, doc
            if let fUrl = fileurl, fileurl != nil {
                let fileName = fUrl.lastPathComponent
                let mimetype = mimeType(for: fileName)
                let haveAccess = fUrl.startAccessingSecurityScopedResource()
                defer {
                    DispatchQueue.main.async {
                        fUrl.stopAccessingSecurityScopedResource()
                    }
                }
                var fileData: Data?
                if haveAccess {
                    fileData = try? Data(contentsOf: fUrl)
                }
                
                // Create multipart body
                let dataBody = createDataBody(fileData: fileData, boundary: boundary, mimetype: mimetype, fileName: fileName, fileURL: fUrl)
                
                // Add Content-Length
                request.setValue(String(dataBody.count), forHTTPHeaderField: "Content-Length")
                request.httpBody = dataBody
            }

            // Add Parameters (Query for GET, Body for others)
            if let parameters = parameters {
                if method == .get {
                    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
                    request.url = components?.url
                } else {
                    if urlencoded {
                        request.httpBody = parameters.percentEncoded()
                    } else {
                        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
                    }
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
                configuration.timeoutIntervalForRequest = timeIntervalRequest
                configuration.timeoutIntervalForResource = timeIntervalResource

                return URLSession(configuration: configuration, delegate: SSLPinningDelegate(), delegateQueue: OperationQueue())
            }()
            
            urlSession.dataTaskPublisher(for: request)
            //URLSession.shared.dataTaskPublisher(for: request)
            
            // 2. Make this process in main thread. (you can do this in background thread as well)
                .receive(on: DispatchQueue.main)
            
            // 3. Use 'tryMap'(Operator) to get the data from the result
                .tryMap({ (data, response) -> (Int, Data) in
                    guard let response = response as? HTTPURLResponse else {
                        throw APIError.unknownError
                    }

                    // ✅ Default accept status codes in [200-209]
                    if successStatusCodes.contains(response.statusCode) {
                        return (response.statusCode, data)
                    } else {
                        // Handle error status codes
                        throw APIError.invalidResponse(statusCode: response.statusCode)
                    }
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
    
    private func createDataBody(withParameters params: [String: Any]?, media: [Media]?, boundary: String) -> Data {
        
        let lineBreak = "\r\n"
        var body = Data()
        
        if let parameters = params {
            for (key, value) in parameters {
                let val = (value as? String) ?? "\(value)"
                body.append("--\(boundary + lineBreak)".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak + lineBreak)".data(using: .utf8)!)
                body.append("\(val + lineBreak)".data(using: .utf8)!)
            }
        }
        if let media = media {
            for photo in media {
                body.append("--\(boundary + lineBreak)".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(photo.key)\"; filename=\"\(photo.filename)\"\(lineBreak)".data(using: .utf8)!)
                body.append("Content-Type: \(photo.mimeType + lineBreak + lineBreak)".data(using: .utf8)!)
                body.append(photo.data)
                body.append(lineBreak.data(using: .utf8)!)
                print("mimeType \(photo.mimeType)")
            }
        }
        body.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)
        
        return body as Data
    }
    
    func generateBoundary() -> String {
        return "Boundary-\(NSUUID().uuidString)"
    }
    
    func mimeType(for path: String) -> String {
        if let mimeType = UTType(filenameExtension: URL(fileURLWithPath: path).pathExtension)?.preferredMIMEType {
            return mimeType
        }
        else {
            return "application/octet-stream"
        }
    }

    private func createDataBody(fileData: Data?, boundary: String, mimetype: String, fileName: String, fileURL: URL?) -> Data {
        var body = Data()
        
        let lineBreak = "\r\n"
        body.append("--\(boundary + lineBreak)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\(lineBreak)".data(using: .utf8)!)
        body.append("Content-Type: \(mimetype + lineBreak + lineBreak)".data(using: .utf8)!)
        if let data = fileData {
            body.append(data)
        } else {
            if let fileurl = fileURL {
                body.append("\(fileurl)".data(using: .utf8)!)
            }
        }
        body.append(lineBreak.data(using: .utf8)!)
        body.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)


        return body
    }

}

extension Dictionary {
    func percentEncoded() -> Data? {
        map { key, value in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return escapedKey + "=" + escapedValue
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }
}

extension UIImage {
    func resized(toWidth width: CGFloat, isOpaque: Bool = true) -> UIImage? {
        let canvas = CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))
        let format = imageRendererFormat
        format.opaque = isOpaque
        return UIGraphicsImageRenderer(size: canvas, format: format).image {
            _ in draw(in: CGRect(origin: .zero, size: canvas))
        }
    }
}
