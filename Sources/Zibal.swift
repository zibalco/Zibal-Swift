//
//  Zibal.swift
//  Zibal-iOS
//
//  Created by Alireza Kamali on 8/9/18.
//

import Foundation

public typealias RequestCompletionHandler = (URLResponse?, Zibal.Error?, Zibal.RequestResponse?) -> Void
public typealias VerifyCompletionHandler = (URLResponse?, Zibal.Error?, Zibal.VerifyResponse?) -> Void

private typealias CompletionHandler = (URLResponse?, Zibal.Error?, Body?) -> Void
private protocol Body: Codable {}
private extension Body {
	func data() throws -> Data {
		let encoder = JSONEncoder()
		return try encoder.encode(self)
	}
	
	func object<T>(type: T.Type, data: Data) throws -> T where T: Decodable {
		let decoder = JSONDecoder()
		return try decoder.decode(type, from: data)
	}
}
private extension Data {
	func decode<T>(type: T.Type) throws -> T where T: Decodable {
		let decoder = JSONDecoder()
		return try decoder.decode(type, from: self)
	}
}


public class Zibal {
	private var config: Config?
	private let apiBase = "https://gateway.zibal.ir"
	
	private init() {
		self.config = nil
	}
	
	public static func `init`(merchant: String, callbackUrl: String, logLevel: LogLevel = .verbose) throws {
		let config = try Config(merchant: merchant, callbackUrl: callbackUrl, logLevel: logLevel)
		shared.config = config
	}
	
	public static func request(amount: Int, mobile: String? = nil, description: String? = nil, orderId: String? = nil, completion: RequestCompletionHandler?) {
		guard let config = shared.config, config.isValid else {
			let error = Error.invalidConfig
			log(error, type: .error)
			completion?(nil, error, nil)
			return
		}
		let body = RequestBody(merchant: config.merchant, callbackUrl: config.callbackUrl, amount: amount, mobile: mobile, description: description, orderId: orderId)
		shared.post(path: "request", body: body, responseType: RequestResponse.self) { (response, error, body) in
			guard let body = body as? RequestResponse else {
				let error = Error.badResponse(response: response)
				log(error, type: .error)
				completion?(nil, error, nil)
				return
			}
			completion?(response, nil, body)
		}
	}
	
	
	public static func verify(trackId: Int, completion: VerifyCompletionHandler?) {
		guard let config = shared.config, config.isValid else {
			let error = Error.invalidConfig
			log(error, type: .error)
			completion?(nil, error, nil)
			return
		}
		let body = VerifyBody(merchant: config.merchant, trackId: trackId)
		shared.post(path: "verify", body: body, responseType: VerifyResponse.self) { (response, error, body) in
			guard let body = body as? VerifyResponse else {
				let error = Error.badResponse(response: response)
				log(error, type: .error)
				completion?(nil, error, nil)
				return
			}
			completion?(response, nil, body)
		}
	}
	
	public static func startURL(for trackId: Int) -> URL? {
		let urlString = "\(shared.apiBase)/start/\(trackId)"
		return URL(string: urlString)
	}
}

public extension Zibal {
	public enum Error: Swift.Error {
		// Internal
		case invalidConfig
		case badURL(url: String)
		case badBody(body: Codable)
		// Endpoint
		case badResponse(response: URLResponse?)
		case badResponseData(data: Data)
		case invalidStatusCode
		
		public var code: Int {
			switch self {
			case .invalidConfig:
				return -100
			case .badURL:
				return -101
			case .badBody:
				return -102
			case .badResponse:
				return -200
			case .badResponseData:
				return -201
			case .invalidStatusCode:
				return -202
			}
		}
		
		public var isInternal: Bool {
			return code < 0 && code > -200
		}
		
		public var message: String {
			switch self {
			case .invalidConfig:
				return "Invalid Configuration"
			case let .badURL(url):
				return "Bad URL: \(url)"
			case let .badBody(body):
				return "Bad Body: \(body)"
			case let .badResponse(response):
				return "Bad Response: \(response.debugDescription)"
			case let .badResponseData(data):
				return "Bad ResponseData: \(data)"
			case .invalidStatusCode:
				return "Invalid Status Code"
			}
		}
	}
	
	public enum Status: Codable {
		// verify status
		case waiting
		case internalError
		case paid(isVerified: Bool)
		case cancelledByUser
		case invalidCardNumber
		case insufficientCredit
		case wrongPassword
		case exceededRequestLimit
		case exceededPaymentLimit
		case exceededPaymentAmount
		case invalidCardIssuer
		case switchFailure
		case inaccessibleCard
		// result status
		case confirmed
		case merchantNotFound
		case merchantInactive
		case merchantInvalid
		case invalidAmountValue
		case invalidCallbackURL
		case alreadyConfirmed
		case incompletePayment
		case invalidTrackId
		
		public func encode(to encoder: Encoder) throws {
			var container = encoder.singleValueContainer()
			try container.encode(code)
		}

		public init(from decoder: Decoder) throws {
			let code = try decoder.singleValueContainer().decode(Int.self)
			guard let status = Status.init(code: code) else {
				throw Error.invalidStatusCode
			}
			self = status
		}

		public init?(code: Int) {
			switch code {
			case -1: self = .waiting
			case -2: self = .internalError
			case 1: self = .paid(isVerified: true)
			case 2: self = .paid(isVerified: false)
			case 3: self = .cancelledByUser
			case 4: self = .invalidCardNumber
			case 5: self = .insufficientCredit
			case 6: self = .wrongPassword
			case 7: self = .exceededRequestLimit
			case 8: self = .exceededPaymentLimit
			case 9: self = .exceededPaymentAmount
			case 10: self = .invalidCardIssuer
			case 11: self = .switchFailure
			case 12: self = .inaccessibleCard
			case 100: self = .confirmed
			case 102: self = .merchantNotFound
			case 103: self = .merchantInactive
			case 104: self = .merchantInvalid
			case 105: self = .invalidAmountValue
			case 106: self = .invalidCallbackURL
			case 201: self = .alreadyConfirmed
			case 202: self = .incompletePayment
			case 203: self = .invalidTrackId
			default: return nil
			}
		}
		
		public var code: Int {
			switch self {
			case .waiting: return -1
			case .internalError: return -2
			case let .paid(isVerified): return isVerified ? 1 : 2
			case .cancelledByUser: return 3
			case .invalidCardNumber: return 4
			case .insufficientCredit: return 5
			case .wrongPassword: return 6
			case .exceededRequestLimit: return 7
			case .exceededPaymentLimit: return 8
			case .exceededPaymentAmount: return 9
			case .invalidCardIssuer: return 10
			case .switchFailure: return 11
			case .inaccessibleCard: return 12
			case .confirmed: return 100
			case .merchantNotFound: return 102
			case .merchantInactive: return 103
			case .merchantInvalid: return 104
			case .invalidAmountValue: return 105
			case .invalidCallbackURL: return 106
			case .alreadyConfirmed: return 201
			case .incompletePayment: return 202
			case .invalidTrackId: return 203
			}
		}
		
		public var message: String {
			switch self {
			case .waiting: return "در انتظار پردخت"
			case .internalError: return "خطای داخلی"
			case let .paid(isVerified):
				return isVerified ?
					"پرداخت شده - تاییدشده" :
				"پرداخت شده - تاییدنشده"
			case .cancelledByUser: return "لغوشده توسط کاربر"
			case .invalidCardNumber: return "شماره کارت نامعتبر می‌باشد"
			case .insufficientCredit: return "موجودی حساب کافی نمی‌باشد"
			case .wrongPassword: return "رمز واردشده اشتباه می‌باشد"
			case .exceededRequestLimit: return "تعداد درخواست‌ها بیش از حد مجاز می‌باشد"
			case .exceededPaymentLimit: return "تعداد پرداخت اینترنتی روزانه بیش از حد مجاز می‌باشد"
			case .exceededPaymentAmount: return "مبلغ پرداخت اینترنتی روزانه بیش از حد مجاز می‌باشد"
			case .invalidCardIssuer: return "صادرکننده‌ی کارت نامعتبر می‌باشد"
			case .switchFailure: return "خطای سوییچ"
			case .inaccessibleCard: return "کارت قابل دسترسی نمی‌باشد"
			case .confirmed: return "با موفقیت تایید شد"
			case .merchantNotFound: return "{merchant} یافت نشد"
			case .merchantInactive: return "{merchant} غیرفعال"
			case .merchantInvalid: return "{merchant} نامعتبر"
			case .invalidAmountValue: return "{amount} بایستی بزرگتر از 1,000 ریال باشد"
			case .invalidCallbackURL: return "{callbackUrl} نامعتبر می‌باشد (شروع با http و یا https)"
			case .alreadyConfirmed: return "قبلا تایید شده"
			case .incompletePayment: return "سفارش پرداخت نشده یا ناموفق بوده است"
			case .invalidTrackId: return "{trackId} نامعتبر می‌باشد"
			}
		}
	}
	
	public enum LogLevel: Int {
		case none = 0
		case error = 1
		case verbose = 2
		
		public var level: String {
			switch self {
			case .error: return "error"
			case .verbose: return "info"
			default: return ""
			}
		}
	}
	
	public struct RequestResponse: Body {
		public let result: Int
		public let message: String
		public let trackId: Int?
		
		public var resultStatus: Status? {
			return Status(code: result)
		}
	}
	
	public struct VerifyResponse: Body {
		public let result: Int
		public let message: String
		public let paidAt: String?
		public let amount: Int?
		public let status: Status?
		
		public var resultStatus: Status? {
			return Status(code: result)
		}
	}
}

private extension Zibal {
	struct Config {
		var merchant: String
		var callbackUrl: String
		var logLevel: LogLevel
		
		init(merchant: String, callbackUrl: String, logLevel: LogLevel) throws {
			self.merchant = merchant
			self.callbackUrl = callbackUrl
			self.logLevel = logLevel
			guard isValid else { throw Error.invalidConfig }
		}
		
		var isValid: Bool {
			let isValid = !merchant.isEmpty && !callbackUrl.isEmpty && URL(string: callbackUrl) != nil
			if !isValid {
				log(Error.invalidConfig.message, type: .error)
			}
			return isValid
		}
	}
	
	struct RequestBody: Body {
		let merchant: String
		let callbackUrl: String
		let amount: Int
		let mobile: String?
		let description: String?
		let orderId: String?
	}
	
	struct VerifyBody: Body {
		let merchant: String
		let trackId: Int
	}
}

private extension Zibal {
	static let shared: Zibal = Zibal.init()
	
	static func log(_ items: Any..., type: LogLevel = .verbose) {
		#if DEBUG
		guard let config = shared.config else { return }
		let logLevel = config.logLevel
		if logLevel.rawValue > 1 || (logLevel.rawValue > 0 && type == .error) {
			let output = items.map { "\($0)" }.joined(separator: " ")
			print("==== Zibal - \(type.level) - \(Date()) -", output)
		}
		#endif
	}
	
	func log(_ items: Any..., type: LogLevel = .verbose) {
		Zibal.log(items, type: type)
	}

	func post<T>(path: String, body: Body, responseType: T.Type, _ completion: @escaping CompletionHandler) where T: Body {
		func complete(with error: Error) {
			log(error, type: .error)
			completion(nil, error, nil)
		}
		
		let urlString = "\(apiBase)/\(path)"
		guard let url = URL(string: urlString) else {
			complete(with: Error.badURL(url: urlString))
			return
		}
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		do {
			let data = try body.data()
			request.httpBody = data
		} catch {
			complete(with: Error.badBody(body: body))
		}
		
		let task = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
			guard let `self` = self else {
				completion(nil, nil, nil)
				return
			}
			self.log("\(path.uppercased()):\n\(response.debugDescription)")
			guard let data = data, error == nil else {
				complete(with: Error.badResponse(response: response))
				return
			}
			do {
				let responseBody = try data.decode(type: responseType)
				self.log(responseBody)
				completion(response, nil, responseBody)
			} catch {
				let error = Error.badResponse(response: response)
				self.log(error, type: .error)
				completion(response, error, nil)
			}
		}
		log("POST: \n\(body))\nTO: \(urlString)")
		task.resume()
	}
}
