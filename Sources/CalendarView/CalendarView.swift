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
	private enum Selection {
		case singleDate(Binding<DateComponents?>)
		case multiDate(Binding<[DateComponents]>)
	}
	
	@Environment(\.calendar) private var calendar
	@Environment(\.locale) private var locale
	@Environment(\.timeZone) private var timeZone
	
	private let availableDateRange: DateInterval
	private let visibleDateComponents: Binding<DateComponents>?
	private let selection: Selection?
	
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
		self.selection = Selection.singleDate(selection)
	}
	
	public init(availableDateRange: DateInterval = .init(start: .distantPast, end: .distantFuture), visibleDateComponents: Binding<DateComponents>, selection: Binding<DateComponents?>) {
		self.availableDateRange = availableDateRange
		self.visibleDateComponents = visibleDateComponents
		self.selection = Selection.singleDate(selection)
	}
	
	public init(availableDateRange: DateInterval = .init(start: .distantPast, end: .distantFuture), selection: Binding<[DateComponents]>) {
		self.availableDateRange = availableDateRange
		self.visibleDateComponents = nil
		self.selection = Selection.multiDate(selection)
	}
	
	public init(availableDateRange: DateInterval = .init(start: .distantPast, end: .distantFuture), visibleDateComponents: Binding<DateComponents>, selection: Binding<[DateComponents]>) {
		self.availableDateRange = availableDateRange
		self.visibleDateComponents = visibleDateComponents
		self.selection = Selection.multiDate(selection)
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
		context.coordinator.isUpdatingView = true
		defer { context.coordinator.isUpdatingView = false }
		
		calendarView.calendar = calendar
		calendarView.locale = locale
		calendarView.timeZone = timeZone
		calendarView.availableDateRange = availableDateRange
		calendarView.fontDesign = fontDesign
		
		let canAnimate = context.transaction.animation != nil
		
		// visible date components
		
		context.coordinator.visibleDateComponents = visibleDateComponents
		
		if let binding = visibleDateComponents {
			let visibleYearMonth = calendarView.visibleDateComponents.yearMonth
			let newYearMonth = binding.wrappedValue.yearMonth
			
			if newYearMonth != visibleYearMonth {
				calendarView.setVisibleDateComponents(newYearMonth, animated: canAnimate || binding.canAnimate)
			}
		}
		
		// decorations
		
		context.coordinator.decoratedComponents = Set(decoratedDateComponents.map(\.yearMonthDay))
		context.coordinator.decoration = decoration
		
		// only reload components that are actually visible to avoid crashes
		if let visibleMonth = calendar.date(from: calendarView.visibleDateComponents) {
			var componentsToReload = [DateComponents]()
			
			for day in calendar.range(of: .day, in: .month, for: visibleMonth)! {
				var components = calendarView.visibleDateComponents
				components.day = day
				componentsToReload.append(components)
			}
			
			calendarView.reloadDecorations(forDateComponents: componentsToReload, animated: canAnimate)
		}
		
		// selection
		
		switch selection {
		case .singleDate(let binding):
			context.coordinator.selectedDate = binding
			
			if let dateSelection = calendarView.selectionBehavior as? UICalendarSelectionSingleDate {
				if dateSelection.selectedDate != binding.wrappedValue {
					dateSelection.setSelected(binding.wrappedValue, animated: canAnimate || binding.canAnimate)
				}
				
				dateSelection.updateSelectableDates()
			} else {
				let dateSelection = UICalendarSelectionSingleDate(delegate: context.coordinator)
				calendarView.selectionBehavior = dateSelection
				dateSelection.setSelected(binding.wrappedValue, animated: canAnimate || binding.canAnimate)
			}
			
		case .multiDate(let binding):
			context.coordinator.selectedDates = binding
			
			if let dateSelections = calendarView.selectionBehavior as? UICalendarSelectionMultiDate {
				if dateSelections.selectedDates != binding.wrappedValue {
					dateSelections.setSelectedDates(binding.wrappedValue, animated: canAnimate || binding.canAnimate)
				}
				
				dateSelections.updateSelectableDates()
			} else {
				let dateSelections = UICalendarSelectionMultiDate(delegate: context.coordinator)
				calendarView.selectionBehavior = dateSelections
				dateSelections.setSelectedDates(binding.wrappedValue, animated: canAnimate || binding.canAnimate)
			}
			
		case nil:
			// setting selectionBehavior reloads the view which can interfere
			// with animations and scrolling, so only set if actually changed
			if calendarView.selectionBehavior != nil {
				calendarView.selectionBehavior = nil
			}
		}
		
		context.coordinator.canSelectDate = canSelectDate
		context.coordinator.canDeselectDate = canDeselectDate
	}
	
	public class Coordinator: NSObject {
		var isUpdatingView = false
		var visibleDateComponents: Binding<DateComponents>?
		var decoratedComponents = Set<DateComponents>()
		var decoration: ((DateComponents) -> UICalendarView.Decoration)?
		var selectedDate: Binding<DateComponents?>?
		var selectedDates: Binding<[DateComponents]>?
		var canSelectDate: ((DateComponents) -> Bool)?
		var canDeselectDate: ((DateComponents) -> Bool)?
	}
	
	public func makeCoordinator() -> Coordinator {
		Coordinator()
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
		view.decoratedDateComponents = dateComponents
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
			if !isUpdatingView, let binding = visibleDateComponents {
				let visibleComponents = calendarView.visibleDateComponents
				
				if binding.wrappedValue.yearMonth != visibleComponents.yearMonth {
					binding.wrappedValue = visibleComponents
				}
			}
		}
		
		if decoratedComponents.contains(dateComponents.yearMonthDay) {
			return decoration?(dateComponents) ?? .default()
		}
		
		return nil
	}
	
	public func calendarView(_ calendarView: UICalendarView, didChangeVisibleDateComponentsFrom previousDateComponents: DateComponents) {
		visibleDateComponents?.wrappedValue = calendarView.visibleDateComponents
	}
}

// MARK: - UICalendarSelectionSingleDateDelegate

extension CalendarView.Coordinator: UICalendarSelectionSingleDateDelegate {
	public func dateSelection(_ selection: UICalendarSelectionSingleDate, canSelectDate dateComponents: DateComponents?) -> Bool {
		if let dateComponents {
			return canSelectDate?(dateComponents) ?? true
		}
		
		if let canDeselectDate, let selectedDate = selection.selectedDate {
			return canDeselectDate(selectedDate)
		}
		
		return false // UICalendarView's default behavior
	}
	
	public func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
		selectedDate?.wrappedValue = dateComponents
	}
}

// MARK: - UICalendarSelectionMultiDateDelegate

extension CalendarView.Coordinator: UICalendarSelectionMultiDateDelegate {
	public func multiDateSelection(_ selection: UICalendarSelectionMultiDate, canSelectDate dateComponents: DateComponents) -> Bool {
		canSelectDate?(dateComponents) ?? true
	}
	
	public func multiDateSelection(_ selection: UICalendarSelectionMultiDate, canDeselectDate dateComponents: DateComponents) -> Bool {
		canDeselectDate?(dateComponents) ?? true
	}
	
	public func multiDateSelection(_ selection: UICalendarSelectionMultiDate, didSelectDate dateComponents: DateComponents) {
		selectedDates?.wrappedValue = selection.selectedDates
	}
	
	public func multiDateSelection(_ selection: UICalendarSelectionMultiDate, didDeselectDate dateComponents: DateComponents) {
		selectedDates?.wrappedValue = selection.selectedDates
	}
}

// MARK: - Helper

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
