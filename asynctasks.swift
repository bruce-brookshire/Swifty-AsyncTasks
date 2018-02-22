// AsyncTasks.swift
// Description: An API based on Java's Executor service API
//
// Created by: Bruce Brookshire
//

import Foundation

fileprivate protocol SwiftyThreadDelegate {
    func getNextTask() -> (() -> Void)?
}

final class ExecutorService: SwiftyThreadDelegate
{
    private var threads: [SwiftyThread]
    private var queue: ArrayBlockingQueue<() -> Void>
    
    init (threadCount: Int = 1, qos: QualityOfService = .default) {
        threads = []
        queue = ArrayBlockingQueue()
        
        for i in 0..<threadCount {
            threads.append(SwiftyThread(delegate: self, qos: qos))
            threads[i].name = String(i)
        }
        
        for thread in threads {
            thread.start()
        }
    }
    
    deinit {
        shutdownNow()
    }
    
    func getNextTask() -> (() -> Void)? {
        queue.lock()
        defer {queue.unlock()}
        
        if queue.size() > 0 {
            return queue.next()
        } else {
            return nil
        }
    }
    
    func submit<T>(callable: Callable<T>) -> Future<T> {
        queue.lock()
        defer {queue.unlock()}
        
        let future = Future<T>()
        let task = { future.set(t: callable.call()) }
        
        queue.insert(task)
        
        return future
    }
    
    func submit(runnable: Runnable) {
        queue.lock()
        defer {queue.unlock()}
        
        let task = { runnable.run() }
        
        queue.insert(task)
    }
    
    func shutdownNow() {
        for thread in threads {
            thread.cancel()
        }
    }
}

fileprivate class SwiftyThread: Thread
{
    private var swifty_delegate: SwiftyThreadDelegate
    
    init(delegate: SwiftyThreadDelegate, qos: QualityOfService) {
        self.swifty_delegate = delegate
        super.init()
        qualityOfService = qos
    }
    
    override func main() {
        while (true) {
            if let task = swifty_delegate.getNextTask(){
                print("executing", Thread.current.name!)
                task()
            } else {
                print("pausing")
                Thread.sleep(forTimeInterval: 2)
            }
        }
    }
}

class ArrayBlockingQueue<T>
{
    private var array: [T] = []
    private var m = pthread_mutex_t()
    
    func insert(_ element: T) {
        print("inserting", array.count + 1)
        array.append(element)
    }
    
    func next() -> T {
        print("returning", array.count)
        return array.remove(at: 0)
    }
    
    func size() -> Int {
        return array.count
    }
    
    func lock() {
        pthread_mutex_lock(&m)
    }
    
    func unlock() {
        pthread_mutex_unlock(&m)
    }
}

class Runnable
{
    func run() {
        print("ran base")
    }
}

class Callable<T>
{
    func call() -> T? {
        print("called base")
        return nil
    }
}

class Future<T>
{
    private var future: T?
    private var futureLock: NSLock
    
    fileprivate init() {
        self.futureLock = NSLock()
        futureLock.lock()
    }
    
    func get() -> T? {
        while (!futureLock.try()) { }
        defer {futureLock.unlock()}
        return future
    }
    
    fileprivate func set(t: T?) {
        future = t
        defer {futureLock.unlock()}
    }
}

class CustomCallable: Callable<Int>
{
    override func call() -> Int? {
        print("subclass called")
        Thread.sleep(forTimeInterval: 2)
        return 1000
    }
}

class CustomRunnable: Runnable
{
    override func run() {
        print("subclass ran")
        Thread.sleep(forTimeInterval: 2)
    }
}
