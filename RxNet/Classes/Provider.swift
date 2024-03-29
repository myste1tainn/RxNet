import Foundation
import RxSwift

enum ProviderError: Error {
  case invalidURL
}

/// A self-mockable network data requester.
final public class Provider<Target: ProductionTargetType> {
  private let stubBehavior: StubBehavior
  private let scheduler:    SchedulerType
  
  /// Initializes a new Provider instance.
  ///
  /// - Parameters:
  ///   - stubBehavior: how stubbing should be done.
  ///   - scheduler: the instance that will schedule delayed responses.
  public init(stubBehavior: StubBehavior = .never,
              scheduler: SchedulerType = ConcurrentDispatchQueueScheduler(qos: .background)) {
    self.stubBehavior = stubBehavior
    self.scheduler = scheduler
  }
  
  public func request(_ target: Target) -> Single<Data> {
    guard let url = URL(string: target.baseURL.absoluteString + target.path) else {
      return .error(ProviderError.invalidURL)
    }
    
    var request = URLRequest(url: url)
    request.allHTTPHeaderFields = target.headers
    request.httpBody = target.task.body
    request.httpMethod = target.task.method.rawValue
    if let parameters = target.task.parameters {
      request = request.addingParameters(parameters)
    }
    
    return URLSessionFactory(target: target)
      .makeURLSession(stubBehavior: stubBehavior, scheduler: scheduler)
      .data(request: request).asSingle()
  }
}

// MARK: - Private
// Entities that are not supposed to be used outside a Provider
private struct ReactiveURLSessionMock: ReactiveURLSessionProtocol {
  fileprivate let stubbed: Observable<Data>
  
  func data(request: URLRequest) -> Observable<Data> {
    return stubbed
  }
}

private struct ReactiveURLSessionDelayableMock: ReactiveURLSessionProtocol {
  fileprivate let stubbed:   Observable<Data>
  fileprivate let scheduler: SchedulerType
  fileprivate let delay:     RxTimeInterval
  
  func data(request: URLRequest) -> Observable<Data> {
    stubbed.delay(delay, scheduler: scheduler)
  }
}

private struct URLSessionFactory<Target: ProductionTargetType> {
  let target: Target
  
  func makeURLSession(stubBehavior: StubBehavior,
                      scheduler: SchedulerType) -> ReactiveURLSessionProtocol {
    switch stubBehavior {
    case .delayed(let time, let stub):
      switch time {
      case let .nanoseconds(unit),
           let .microseconds(unit),
           let .milliseconds(unit),
           let .seconds(unit):
        if unit > 0 {
          return ReactiveURLSessionDelayableMock(stubbed: target.makeResponse(from: stub),
                                                 scheduler: scheduler,
                                                 delay: time)
        } else {
          return ReactiveURLSessionMock(stubbed: target.makeResponse(from: stub))
        }
      case .never:
        return URLSession.shared.rx
      @unknown default:
        return URLSession.shared.rx
      }
    case .immediate(let stub):
      return ReactiveURLSessionMock(stubbed: target.makeResponse(from: stub))
    case .never:
      return URLSession.shared.rx
    }
  }
}
