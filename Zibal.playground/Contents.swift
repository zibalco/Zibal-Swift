import Zibal

try? Zibal.init(merchant: "zibal", callbackUrl: "https://alireza.app")

Zibal.request(amount: 1500) { (response, error, object) in
	print("============================Response======================")
	print(response)
	print("============================Error=========================")
	print(error)
	print("============================Object========================")
	print(object)
	print(object?.resultStatus)
	print("============================")
	
	guard let trackId = object?.trackId else { return }
	Zibal.verify(trackId: trackId, completion: { (response, error, object) in
		print("============================Response======================")
		print(response)
		print("============================Error=========================")
		print(error)
		print("============================Object========================")
		print(object)
		print(object?.resultStatus)
		print("============================")
	})
}

