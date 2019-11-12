import Foundation
import RxSwift
import RxCocoa

protocol ReactiveURLSessionProtocol {
    func data(request: URLRequest) -> Observable<Data>
}

extension Reactive: ReactiveURLSessionProtocol where Base: URLSession {}
