﻿
typealias Block = (_ sender: Notification)->()

#if TOFFEE
public typealias Notification = NSNotification
/*public __mapped class Notification => NSNotification {
	public var data: ImmutableDictionary<String,Object>? {
		get {
			return __mapped.userInfo
		}
	}
	init(object: Object?, data: ImmutableDictionary<String,Object>?) {
		let result = NSNotification(name: "Notification", object: object, userInfo: data)
	}
}*/
#else
public class Notification {
	public private(set) var object: Object?
	public private(set) var data: ImmutableDictionary<String,Object>?

	init(object: Object?, data: ImmutableDictionary<String,Object>?) {
		self.object = object
		self.data = data
	}
}
#endif

public static class RemObjects.Elements.RTL.BroadcastManager {

	#if TOFFEE
	private let subscriptions = Dictionary<String,List<(Object,Object?,id)>>() // receiver, object, token
	#else
	private let subscriptions = Dictionary<String,List<(Object,Object?,Block)>>()    // receiver, block
	#endif

	//func subscribe(_ object: Object, toBroadcast broadcast: String, block: (Dictionary<String,Any>)->()) {
	//}

	public func subscribe(_ receiver: Object, toBroadcast broadcast: String, block: (_ sender: Notification)->()) {
		subscribe(receiver, toBroadcast: broadcast, block: block, object: nil)
	}

	public func subscribe(_ receiver: Object, toBroadcast broadcast: String, block: (_ sender: Notification)->(), object: Object?) {
		#if TOFFEE
		let token = NSNotificationCenter.defaultCenter.addObserver(for: broadcast, object: object, queue: nil, usingBlock: block);
		__lock self {
			var subs = subscriptions[broadcast]
			if subs == nil {
				subs = List<(Object,Object?,id)>()
				subscriptions[broadcast] = subs
			}
			subs!.Add((receiver, object, token))
		}
		#else
		__lock self {
			var subs = subscriptions[broadcast]
			if subs == nil {
				subs = List<(Object,Object?,Block)>()
				subscriptions[broadcast] = subs
			}
			subs!.Add((receiver, object, block))
		}
		#endif
	}

	public func subscribe(_ receiver: Object, toBroadcasts broadcasts: List<String>, block: (_ sender: Notification)->()) {
		subscribe(receiver, toBroadcasts: broadcasts, block: block, object: nil)
	}

	public func subscribe(_ receiver: Object, toBroadcasts broadcasts: List<String>, block: (_ sender: Notification)->(), object: Object?) {
		for b in broadcasts {
			subscribe(receiver, toBroadcast: b, block: block, object: object)
		}
	}

	#if TOFFEE
	public func subscribe(_ receiver: Object, selector: SEL, toBroadcast broadcast: String, object: Object? = nil) {
		NSNotificationCenter.defaultCenter.addObserver(receiver, selector: selector, name: broadcast, object: object)
	}
	#endif

	public func unsubscribe(_ receiver: Object, fromBroadcast broadcast: String) {
		#if TOFFEE
		NSNotificationCenter.defaultCenter.removeObserver(receiver, name: broadcast, object: nil)
		__lock self {
			if let subs = subscriptions[broadcast] {
				for s in subs {
					if s.0 == receiver {
						NSNotificationCenter.defaultCenter.removeObserver(s.2)
						subs.Remove(s)
					}
				}
			}
		}
		#else
		__lock self {
			if let subs = subscriptions[broadcast] {
				for s in subs {
					if s.0 == receiver {
						subs.Remove(s)
					}
				}
			}
		}
		#endif
	}

	public func unsubscribe(_ receiver: Object) {
		#if TOFFEE
		NSNotificationCenter.defaultCenter.removeObserver(receiver)
		__lock self {
			for subs in subscriptions.Values {
				for s in subs {
					if s.0 == receiver {
						NSNotificationCenter.defaultCenter.removeObserver(s.2)
						subs.Remove(s)
					}
				}
			}
		}
		#else
		__lock self {
			for k in subscriptions.Keys {
				if let subs = subscriptions[k] {
					for s in subs? {
						if s.0 == receiver {
							subs.Remove(s)
						}
					}
				}
			}
		}
		#endif
	}

	@inline(always)
	private func syncToMainThreadIfNeeded(sync: Boolean, block: () -> ()) {
		#if TOFFEE
		if sync {
			dispatch_async(dispatch_get_main_queue(), block)
		} else {
			block()
		}
		#else
		if sync {
			#warning syncToMainThreadIfNeeded() is not implemented for non-Toffee
			block()
		} else {
			block()
		}
		#endif
	}

	public func submitBroadcast(_ broadcast: String, object: Object? = nil, data: ImmutableDictionary<String,Object>? = nil, syncToMainThread: Boolean = false) {
		syncToMainThreadIfNeeded(sync: syncToMainThread) {

			#if TOFFEE
			NSNotificationCenter.defaultCenter.postNotificationName(broadcast, object: object, userInfo: data)
			#else
			__lock self {
				for s in subscriptions[broadcast] {
					s.2(Notification(object: object, data: data))
				}
			}
			#endif
		}
	}
}