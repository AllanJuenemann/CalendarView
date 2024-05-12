# CalendarView

CalendarView makes UIKit's [UICalendarView](https://developer.apple.com/documentation/uikit/uicalendarview) with all its features available to SwiftUI.

Please note that `UICalendarView` uses [DateComponents](https://developer.apple.com/documentation/foundation/datecomponents) rather than [Date](https://developer.apple.com/documentation/foundation/date). CalendarView uses the same convention for consistency but might add support for `Date` in the future.

## Usage

### Displaying the calendar

```swift
import SwiftUI
import CalendarView

var body: some View {
  CalendarView()
}
```

<img src="/Images/calendar.png" width="200px" />

### Configuring the calendar

CalendarView uses the [calendar](https://developer.apple.com/documentation/swiftui/environmentvalues/calendar), [time zone](https://developer.apple.com/documentation/swiftui/environmentvalues/timezone) and [locale](https://developer.apple.com/documentation/swiftui/environmentvalues/locale) from the environment.

```swift
CalendarView()
  .environment(\.locale, .init(identifier: "ja"))
```

<img src="/Images/calendar_ja.png" width="200px" />

The [font design](https://developer.apple.com/documentation/uikit/uifontdescriptor/systemdesign) can be configured by using the `fontDesign` modifier.

```swift
CalendarView()
  .fontDesign(.serif)
```

<img src="/Images/calendar_serif.png" width="200px" />

You can also set the available date range.

```swift
CalendarView(availableDateRange: specialEvent)
```

<img src="/Images/calendar_range.png" width="200px" />

### Updating visible components

You can set and update the current components (year, month) that should be visible in the calendar.

```swift
VStack {
  CalendarView(visibleDateComponents: $visibleComponents)
  
  Button("Today") {
    withAnimation {
      visibleComponents = calendar.dateComponents([.year, .month], from: .now)
    }
  }
}
```

### Using decorations

Use the `decorating` modifier to decorate specific days. 

```swift
CalendarView()
  .decorating([DateComponents(day: 16)])
```

Decorations can also be customized.

```swift
CalendarView()
  .decorating(specialDates, systemImage: "star.fill", color: .yellow)
  .decorating(otherDates, color: .green, size: .large)
```

<img src="/Images/calendar_decorations.png" width="200px" />

### Handling selections

CalendarView supports selections of single and multiple dates.

```swift
CalendarView(selection: $selectedDates)
```

<img src="/Images/calendar_selections.png" width="200px" />

You can also configure which dates are selectable and deselectable.

```swift
CalendarView(selection: $selectedDates)
  .selectable { dateComponents in
    dateComponents.day > 15
  }
  .deselectable { dateComponents in
    dateComponents.year == currentYear && dateComponents.month == currentMonth
  }
```
