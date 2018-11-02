import Foundation
import RxSwift
import Alamofire
import ObjectMapper

enum ApiError: Error {
    case invalidRequest
    case mappingError
    case noConnection
    case serverError(status: Int, data: Any?)
}

protocol IApiManager {
    func request(withMethod method: HTTPMethod, path: String, parameters: [String: Any]?) -> URLRequestConvertible
    func observable<T>(forRequest request: URLRequestConvertible, mapper: @escaping (Any) -> T?) -> Observable<T>
    func observable<T: ImmutableMappable>(forRequest request: URLRequestConvertible) -> Observable<[T]>
    func observable<T: ImmutableMappable>(forRequest request: URLRequestConvertible) -> Observable<T>
}

class RequestRouter: URLRequestConvertible {

    private let request: URLRequest
    private let encoding: ParameterEncoding
    private let parameters: [String: Any]?

    init(request: URLRequest, encoding: ParameterEncoding, parameters: [String: Any]?) {
        self.request = request
        self.encoding = encoding
        self.parameters = parameters
    }

    func asURLRequest() throws -> URLRequest {
        return try encoding.encode(request, with: parameters)
    }

}

class ApiManager: IApiManager {
    private let apiUrl: String

    required init(apiUrl: String) {
        self.apiUrl = apiUrl
    }

    func request(withMethod method: HTTPMethod, path: String, parameters: [String: Any]? = nil) -> URLRequestConvertible {
        let baseUrl = URL(string: apiUrl)!
        var request = URLRequest(url: baseUrl.appendingPathComponent(path))
        request.httpMethod = method.rawValue

        request.setValue("application/json", forHTTPHeaderField: "Accept")

        Logger.shared.log(self, "API OUT: \(method.rawValue) \(path) \(parameters.map { String(describing: $0) } ?? "")")

        return RequestRouter(request: request, encoding: method == .get ? URLEncoding.default : JSONEncoding.default, parameters: parameters)
    }

    private func observable(forRequest request: URLRequestConvertible) -> Observable<DataResponse<Any>> {
        let observable = Observable<DataResponse<Any>>.create { observer in
            let requestReference = Alamofire.request(request)
                    .validate()
                    .responseJSON(queue: DispatchQueue.global(qos: .background), completionHandler: { response in
                        observer.onNext(response)
                        observer.onCompleted()
                    })

            return Disposables.create {
                requestReference.cancel()
            }
        }

        return observable.do(onNext: { dataResponse in
            switch dataResponse.result {
            case .success(let result):
                Logger.shared.log(self, "API IN: SUCCESS: \(dataResponse.request?.url?.path ?? ""): response = \(result)")
                ()
            case .failure:
                let data = dataResponse.data.flatMap {
                    try? JSONSerialization.jsonObject(with: $0, options: .allowFragments)
                }

                Logger.shared.log(self, "API IN: ERROR: \(dataResponse.request?.url?.path ?? ""): status = \(dataResponse.response?.statusCode ?? 0), response: \(data.map { "\($0)" } ?? "nil")")
                ()
            }
        })

    }

    func observable<T>(forRequest request: URLRequestConvertible, mapper: @escaping (Any) -> T?) -> Observable<T> {
        return self.observable(forRequest: request)
                .flatMap { dataResponse -> Observable<T> in
                    switch dataResponse.result {
                    case .success(let result):
                        if let value = mapper(result) {
                            return Observable.just(value)
                        } else {
                            return Observable.error(ApiError.mappingError)
                        }
                    case .failure:
                        if let response = dataResponse.response {
                            let data = dataResponse.data.flatMap { try? JSONSerialization.jsonObject(with: $0, options: .allowFragments) }
                            return Observable.error(ApiError.serverError(status: response.statusCode, data: data))
                        } else {
                            return Observable.error(ApiError.noConnection)
                        }
                    }
                }
    }

    func observable<T: ImmutableMappable>(forRequest request: URLRequestConvertible) -> Observable<[T]> {
        return observable(forRequest: request, mapper: { json in
            if let jsonArray = json as? [[String: Any]] {
                return jsonArray.compactMap { try? T(JSONObject: $0) }
            }
            return nil
        })
    }

    func observable<T: ImmutableMappable>(forRequest request: URLRequestConvertible) -> Observable<T> {
        return observable(forRequest: request, mapper: { json in
            if let jsonObject = json as? [String: Any], let object = try? T(JSONObject: jsonObject) {
                return object
            }
            return nil
        })
    }

}

struct AddressResponse: ImmutableMappable {
    let blocks: [BlockResponse]

    init(map: Map) throws {
        blocks = try map.value("blocks")
    }

}

class ApiAddressTxResponse {
    let totalCount: Int
    let page: Int
    let pageSize: Int
    let list: Set<BlockResponse>

    init(totalCount: Int = 0, page: Int = 0, pageSize: Int = 1, list: Set<BlockResponse> = Set()) {
        self.totalCount = totalCount
        self.page = page
        self.pageSize = pageSize
        self.list = list
    }

}

struct BlockResponse: ImmutableMappable, Hashable {
    let hash: String
    let height: Int

    init(hash: String, height: Int) {
        self.hash = hash
        self.height = height
    }

    init(map: Map) throws {
        hash = try map.value("hash")
        height = try map.value("height")
    }

    static func ==(lhs: BlockResponse, rhs: BlockResponse) -> Bool {
        return lhs.height == rhs.height && lhs.hash == rhs.hash
    }

}
