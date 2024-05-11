//
//  CalendarView.swift
//
//  Copyright (c) 2022 Allan Juenemann
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import SwiftUI

public struct CalendarView: UIViewRepresentable {
	@Environment(\.calendar) private var calendar
	@Environment(\.locale) private var locale
	@Environment(\.timeZone) private var timeZone
	
	private let availableDateRange: DateInterval
	private let visibleDateComponents: Binding<DateComponents>?
	private var selection: Binding<DateComponents?>?
	private var selections: Binding<[DateComponents]>?
	
	private var fontDesign = UIFontDescriptor.SystemDesign.default
	private var canSelectDate: ((DateComponents) -> Bool)?
	private var selectableChangeValue: (any Equatable)?
	private var canDeselectDate: ((DateComponents) -> Bool)?
	private var decoratedDateComponents = Set<DateComponents>()
	private var decoration: ((DateComponents) -> UICalendarView.Decoration)?
	private var decorationChangeValue: (any Equatable)?
	
	// MARK: Initializers
	
	public init(availableDateRange: DateInterval = .init(start: .distantPast, end: .distantFuture)) {
		self.availableDateRange = availableDateRange
		self.visibleDateComponents = nil
		self.selection = nil
	}
	
	public init(availableDateRange: DateInterval = .init(start: .distantPast, end: .distantFuture), visibleDateComponents: Binding<DateComponents>) {
		self.availableDateRange = availableDateRange
		self.visibleDateComponents = visibleDateComponents
		self.selection = nil
	}
	
	public init(availableDateRange: DateInterval = .init(start: .distantPast, end: .distantFuture), selection: Binding<DateComponents?>) {
		self.availableDateRange = availableDateRange
		self.visibleDateComponents = nil
		self.selection = selection
		self.selections = nil
	}
	
	public init(availableDateRange: DateInterval = .init(start: .distantPast, end: .distantFuture), visibleDateComponents: Binding<DateComponents>, selection: Binding<DateComponents?>) {
		self.availableDateRange = availableDateRange
		self.visibleDateComponents = visibleDateComponents
		self.selection = selection
		self.selections = nil
	}
	
	public init(availableDateRange: DateInterval = .init(start: .distantPast, end: .distantFuture), selection: Binding<[DateComponents]>) {
		self.availableDateRange = availableDateRange
		self.visibleDateComponents = nil
		self.selections = selection
		self.selection = nil
	}
	
	public init(availableDateRange: DateInterval = .init(start: .distantPast, end: .distantFuture), visibleDateComponents: Binding<DateComponents>, selection: Binding<[DateComponents]>) {
		self.availableDateRange = availableDateRange
		self.visibleDateComponents = visibleDateComponents
		self.selections = selection
		self.selection = nil
	}
	
	// MARK: - UIViewRepresentable
	
	public func makeUIView(context: Context) -> UICalendarView {
		let calendarView = UICalendarView()
		calendarView.delegate = context.coordinator
		
		// must use low compression resistance for horizontal padding and frame modifiers to work properly
		calendarView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		
		return calendarView
	}
	
	public func updateUIView(_ calendarView: UICalendarView, context: Context) {
		context.coordinator.parent = self
		
		context.coordinator.isUpdatingView = true
		defer { context.coordinator.isUpdatingView = false }
		
		calendarView.calendar = calendar
		calendarView.locale = locale
		calendarView.timeZone = timeZone
		calendarView.availableDateRange = availableDateRange
		calendarView.fontDesign = fontDesign
		
		let canAnimate = context.transaction.animation != nil
		
		// visible date components
		
		if let binding = visibleDateComponents {
			let visibleYearMonth = calendarView.visibleDateComponents.yearMonth
			let newYearMonth = binding.wrappedValue.yearMonth
			
			if newYearMonth != visibleYearMonth {
				calendarView.setVisibleDateComponents(newYearMonth, animated: canAnimate || binding.canAnimate)
			}
		}
		
		// decorations
		
		calendarView.reloadDecorationsForVisibleMonth(animated: canAnimate)
		
		// selection
		
		if let selection {
			if let dateSelection = calendarView.selectionBehavior as? UICalendarSelectionSingleDate {
				if dateSelection.selectedDate != selection.wrappedValue {
					dateSelection.setSelected(selection.wrappedValue, animated: canAnimate || selection.canAnimate)
				}
				
				dateSelection.updateSelectableDates()
			} else {
				let dateSelection = UICalendarSelectionSingleDate(delegate: context.coordinator)
				calendarView.selectionBehavior = dateSelection
				dateSelection.setSelected(selection.wrappedValue, animated: canAnimate || selection.canAnimate)
			}
		} else if let selections {
			if let dateSelections = calendarView.selectionBehavior as? UICalendarSelectionMultiDate {
				if dateSelections.selectedDates != selections.wrappedValue {
					dateSelections.setSelectedDates(selections.wrappedValue, animated: canAnimate || selections.canAnimate)
				}
				
				dateSelections.updateSelectableDates()
			} else {
				let dateSelections = UICalendarSelectionMultiDate(delegate: context.coordinator)
				calendarView.selectionBehavior = dateSelections
				dateSelections.setSelectedDates(selections.wrappedValue, animated: canAnimate || selections.canAnimate)
			}
		} else {
			// setting selectionBehavior reloads the view which can interfere
			// with animations and scrolling, so only set if actually changed
			if calendarView.selectionBehavior != nil {
				calendarView.selectionBehavior = nil
			}
		}
	}
	
	public class Coordinator: NSObject {
		var parent: CalendarView
		var isUpdatingView = false
		
		init(_ parent: CalendarView) {
			self.parent = parent
		}
	}
	
	public func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}
}

// MARK: - Font Design

public extension CalendarView {
	func fontDesign(_ design: Font.Design) -> Self {
		var view = self
		
		switch design {
		case .default:
			view.fontDesign = .default
			
		case .serif:
			view.fontDesign = .serif
			
		case .rounded:
			view.fontDesign = .rounded
			
		case .monospaced:
			view.fontDesign = .monospaced
			
		@unknown default:
			view.fontDesign = .default
		}
		
		return view
	}
}

// MARK: - Decorations

public extension CalendarView {
	func decorating(_ dateComponents: Set<DateComponents>, updatingOnChangeOf value: (any Equatable)? = nil, decoration: ((DateComponents) -> UICalendarView.Decoration)? = nil) -> Self {
		var view = self
		view.decoratedDateComponents = Set(dateComponents.map(\.yearMonthDay))
		view.decoration = decoration
		view.decorationChangeValue = value
		return view
	}
}

// MARK: - Selections

public extension CalendarView {
	func selectable(updatingOnChangeOf value: (any Equatable)? = nil, canSelectDate: @escaping (DateComponents) -> Bool) -> Self {
		var view = self
		view.canSelectDate = canSelectDate
		view.selectableChangeValue = value
		return view
	}
	
	func deselectable(canDeselectDate: @escaping (DateComponents) -> Bool) -> Self {
		var view = self
		view.canDeselectDate = canDeselectDate
		return view
	}
	
	func deselectable(_ canDeselectDates: Bool = true) -> Self {
		deselectable { _ in canDeselectDates }
	}
}

// MARK: - UICalendarViewDelegate

extension CalendarView.Coordinator: UICalendarViewDelegate {
	public func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
		if #unavailable(iOS 16.2) {
			// UICalendarView doesn't provide a way to get notified when property visibleDateComponents changes.
			// However, this delegate method is called whenever the user scrolls the view, which in turn
			// allows us to read the current value of visibleDateComponents and update the binding.
			if !isUpdatingView, let binding = parent.visibleDateComponents {
				let visibleComponents = calendarView.visibleDateComponents
				
				if binding.wrappedValue.yearMonth != visibleComponents.yearMonth {
					binding.wrappedValue = visibleComponents
				}
			}
		}
		
		if parent.decoratedDateComponents.contains(year: dateComponents.year, month: dateComponents.month, day: dateComponents.day) {
			return parent.decoration?(dateComponents) ?? .default()
		}
		
		return nil
	}
	
	public func calendarView(_ calendarView: UICalendarView, didChangeVisibleDateComponentsFrom previousDateComponents: DateComponents) {
		parent.visibleDateComponents?.wrappedValue = calendarView.visibleDateComponents
	}
}

// MARK: - UICalendarSelectionSingleDateDelegate

extension CalendarView.Coordinator: UICalendarSelectionSingleDateDelegate {
	public func dateSelection(_ selection: UICalendarSelectionSingleDate, canSelectDate dateComponents: DateComponents?) -> Bool {
		if let dateComponents {
			return parent.canSelectDate?(dateComponents) ?? true
		}
		
		if let canDeselectDate = parent.canDeselectDate, let selectedDate = selection.selectedDate {
			return canDeselectDate(selectedDate)
		}
		
		return false // UICalendarView's default behavior
	}
	
	public func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
		parent.selection?.wrappedValue = dateComponents
	}
}

// MARK: - UICalendarSelectionMultiDateDelegate

extension CalendarView.Coordinator: UICalendarSelectionMultiDateDelegate {
	public func multiDateSelection(_ selection: UICalendarSelectionMultiDate, canSelectDate dateComponents: DateComponents) -> Bool {
		parent.canSelectDate?(dateComponents) ?? true
	}
	
	public func multiDateSelection(_ selection: UICalendarSelectionMultiDate, canDeselectDate dateComponents: DateComponents) -> Bool {
		parent.canDeselectDate?(dateComponents) ?? true
	}
	
	public func multiDateSelection(_ selection: UICalendarSelectionMultiDate, didSelectDate dateComponents: DateComponents) {
		parent.selections?.wrappedValue = selection.selectedDates
	}
	
	public func multiDateSelection(_ selection: UICalendarSelectionMultiDate, didDeselectDate dateComponents: DateComponents) {
		parent.selections?.wrappedValue = selection.selectedDates
	}
}

// MARK: - Helper

private extension Set<DateComponents> {
	func contains(year: Int?, month: Int?, day: Int?) -> Bool {
		contains(.init(year: year, month: month, day: day)) ||
		contains(.init(month: month, day: day)) ||
		contains(.init(day: day))
	}
}

private extension DateComponents {
	var yearMonth: DateComponents {
		DateComponents(year: year, month: month)
	}
	
	var yearMonthDay: DateComponents {
		DateComponents(year: year, month: month, day: day)
	}
}

private extension Binding {
	var canAnimate: Bool {
		transaction.animation != nil
	}
}

// MARK: - Preview

struct CalendarView_Previews: PreviewProvider {
	static var previews: some View {
		CalendarView()
	}
}
