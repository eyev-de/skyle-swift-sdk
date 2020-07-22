//
//  ObservableArray.swift
//  Skyle
//
//  Created by Konstantin Wachendorff on 14.07.20.
//  Copyright © 2020 eyeV GmbH.
//

import Foundation
import Combine

public class ObservableArray<T: ObservableObject>: ObservableObject {
    @Published public var array:[T] = []
    private var cancellables = [AnyCancellable]()

    public init() {}

    public init(array: [T]) {
        self.array = array
        self.observeChildrenChanges()
    }

    public func append(_ element: T) {
        element.objectWillChange.sink(receiveValue: { _ in self.objectWillChange.send() }).store(in: &self.cancellables)
        self.array.append(element)
    }

    public var isEmpty: Bool {
        return self.array.isEmpty
    }

    private func observeChildrenChanges() {
        self.array.forEach({
            $0.objectWillChange.sink(receiveValue: { _ in self.objectWillChange.send() }).store(in: &self.cancellables)
        })
    }

    deinit {
        self.cancellables.removeAll()
    }

}
