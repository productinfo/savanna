//
//  DocumentViewController.swift
//  Savanna iOS
//
//  Created by Louis D'hauwe on 30/12/2016.
//  Copyright © 2016 Silver Fox. All rights reserved.
//

import UIKit
import SavannaKit
import Lioness
import Cub

class DocumentViewController: UIViewController {

	var document: Document?

	@IBOutlet weak var consoleLogTextView: UITextView!
	@IBOutlet weak var sourceTextView: SyntaxTextView!

	@IBOutlet weak var stackView: UIStackView!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		sourceTextView.delegate = self
		
//		self.navigationController?.navigationBar.shadowImage = UIImage()
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_ :)), name: .UIKeyboardWillChangeFrame, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_ :)), name: .UIKeyboardWillHide, object: nil)

		sourceTextView.text = ""
		
		document?.open(completionHandler: { [weak self] (success) in
			
			guard let `self` = self else {
				return
			}
			
			if success {
				
				self.sourceTextView.text = self.document?.text ?? ""
				
				// Calculate layout for full document, so scrolling is smooth.
//				self.sourceTextView.layoutManager.ensureLayout(forCharacterRange: NSRange(location: 0, length: self.textView.text.count))
				
			} else {
				
				self.showAlert("Error", message: "Document could not be opened.", dismissCallback: {
					self.dismiss(animated: true, completion: nil)
				})
				
			}
			
		})
		
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		sourceTextView.tintColor = self.view.tintColor
		
	}
	
	@objc func keyboardWillHide(_ notification: NSNotification) {

		guard let userInfo = notification.userInfo else {
			return
		}
		
		updateForKeyboard(with: userInfo, to: 0.0)

	}
	
	@objc func keyboardWillChangeFrame(_ notification: NSNotification) {
		guard let userInfo = notification.userInfo else {
			return
		}
		
		let endFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
	
		var bottomInset = endFrame?.size.height ?? 0.0
		
		if stackView.axis == .vertical {
			bottomInset -= consoleLogTextView.bounds.height
		}
		
		updateForKeyboard(with: userInfo, to: bottomInset)

	}
	
	func updateForKeyboard(with info: [AnyHashable : Any], to bottomInset: CGFloat) {

		let duration = (info[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.0
		let animationCurveRawNSN = info[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber
		let animationCurveRaw = animationCurveRawNSN?.uintValue ?? UIViewAnimationOptions.curveEaseInOut.rawValue
		let animationCurve = UIViewAnimationOptions(rawValue: animationCurveRaw)
		
		UIView.animate(withDuration: duration, delay: 0.0, options: [animationCurve], animations: {
			
			self.sourceTextView.contentInset.bottom = bottomInset
			
		}, completion: nil)
		
	}
	
	@IBAction func toggleAxis(_ sender: UIBarButtonItem) {
	
		UIView.animate(withDuration: 0.3) {
			
			if self.stackView.axis == .horizontal {
				self.stackView.axis = .vertical
			} else {
				self.stackView.axis = .horizontal
			}
			
		}
		
	}
	
	@IBAction func runSource(_ sender: UIBarButtonItem) {
		
		consoleLogTextView.text = ""
		
		let runner = Cub.Runner(logDebug: false, logTime: false)
		runner.delegate = self
		
		runner.registerExternalFunction(name: "print", argumentNames: ["input"], returns: true) { (args, completionHandler) in
			
			guard let input = args["input"] else {
				_ = completionHandler(.string(""))
				return
			}
			
			let parameter = input.description(with: runner.compiler)
			
			DispatchQueue.main.async {
				self.consoleLogTextView.text = self.consoleLogTextView.text + "\(parameter)\n"
			}
			
			
			_ = completionHandler(.string(""))
		}
		
		let source = self.sourceTextView.text
		
		DispatchQueue.global(qos: .background).async {
			
			do {
				try runner.run(source)
				
				DispatchQueue.main.async {
//					self.progressToolbarItem.text = "Finished running"
				}
				
			} catch {
				print(error)
				DispatchQueue.main.async {
					
					let errorString: String
					
					if let displayableError = error as? Cub.DisplayableError {
						
						errorString = displayableError.description(inSource: source)
						
					} else {
						
						errorString = "Unknown error occurred"

					}
					
					self.consoleLogTextView.text = self.consoleLogTextView.text + "\(errorString)\n"
				}
				
			}
			
		}
		
	}
	
	
	@IBAction func dismissDocumentViewController() {
		
		let currentText = self.document?.text ?? ""
		
		self.document?.text = self.sourceTextView.text
		
		if currentText != self.sourceTextView.text {
			self.document?.updateChangeCount(.done)
		}
		
		dismiss(animated: true) {
			self.document?.close(completionHandler: nil)
		}
	}
	
}

extension DocumentViewController: Cub.RunnerDelegate {
	
	@nonobjc func log(_ message: String) {
		// TODO: refactor to function, scroll to bottom
		consoleLogTextView.text! += "\n\(message)"

		print(message)
	}
	
	@nonobjc func log(_ error: Error) {
		
		consoleLogTextView.text! += "\n\(error)"

		print(error)
	}
	
	@nonobjc func log(_ token: Cub.Token) {
		
		consoleLogTextView.text! += "\n\(token)"

		print(token)
	}
	
}

extension DocumentViewController: SyntaxTextViewDelegate {
	
	func didChangeText(_ syntaxTextView: SyntaxTextView) {
		
	}
	
	func lexerForSource(_ source: String) -> SavannaKit.Lexer {
		return Cub.Lexer(input: source)
	}
	
}

extension Cub.TokenType: SavannaKit.TokenType {
	
	public var syntaxColorType: SyntaxColorType {
		
		switch self {
		case .booleanAnd, .booleanNot, .booleanOr:
			return .plain
			
		case .shortHandAdd, .shortHandDiv, .shortHandMul, .shortHandPow, .shortHandSub:
			return .plain
			
		case .equals, .notEqual, .dot, .ignoreableToken, .parensOpen, .parensClose, .curlyOpen, .curlyClose, .comma:
			return .plain
			
		case .comparatorEqual, .comparatorLessThan, .comparatorGreaterThan, .comparatorLessThanEqual, .comparatorGreaterThanEqual:
			return .plain
			
		case .string:
			return .string
			
		case .other:
			return .plain
			
		case .break, .continue, .function, .if, .else, .while, .for, .do, .times, .return, .returns, .repeat, .true, .false, .struct, .guard, .in, .nil:
			return .keyword
			
		case .comment:
			return .comment
			
		case .number:
			return .number
			
		case .identifier:
			return .identifier
			
		case .squareBracketOpen:
			return .plain

		case .squareBracketClose:
			return .plain

		}
		
	}
	
}

extension Cub.Token: SavannaKit.Token {
	
	public var skRange: Range<Int>? {
		return self.range
	}
	
	public var savannaTokenType: SavannaKit.TokenType {
		return self.type
	}
	
}

extension Cub.Lexer: SavannaKit.Lexer {
	
	public func lexerForInput(_ input: String) -> SavannaKit.Lexer {
		return Cub.Lexer(input: input)
	}
	
	public func getSavannaTokens() -> [SavannaKit.Token] {
		return self.tokenize()
	}
	
}

extension Lioness.TokenType: SavannaKit.TokenType {
	
	public var syntaxColorType: SyntaxColorType {
		
		switch self {
		case .booleanAnd, .booleanNot, .booleanOr:
			return .plain
			
		case .shortHandAdd, .shortHandDiv, .shortHandMul, .shortHandPow, .shortHandSub:
			return .plain
			
		case .equals, .notEqual, .dot, .ignoreableToken, .parensOpen, .parensClose, .curlyOpen, .curlyClose, .comma:
			return .plain
			
		case .comparatorEqual, .comparatorLessThan, .comparatorGreaterThan, .comparatorLessThanEqual, .comparatorGreaterThanEqual:
			return .plain
			
		case .other:
			return .plain
			
		case .break, .continue, .function, .if, .else, .while, .for, .do, .times, .return, .returns, .repeat, .true, .false, .struct:
			return .keyword
			
		case .comment:
			return .comment
			
		case .number:
			return .number
			
		case .identifier:
			return .identifier
			
		}
		
	}
	
}

extension Lioness.Token: SavannaKit.Token {
	public var skRange: Range<Int>? {
		return self.range
	}
	
	
	public var savannaTokenType: SavannaKit.TokenType {
		return self.type
	}
	
}

extension Lioness.Lexer: SavannaKit.Lexer {
	
	public func lexerForInput(_ input: String) -> SavannaKit.Lexer {
		return Lioness.Lexer(input: input)
	}
	
	public func getSavannaTokens() -> [SavannaKit.Token] {
		return self.tokenize()
	}
	
}
