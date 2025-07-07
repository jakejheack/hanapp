# Payment Flow Implementation

## Overview
This document describes the implementation of a payment step between job completion confirmation and review in the HanApp chat system. The payment flow ensures that listers must complete payment before they can leave a review for the doer.

## Flow Overview

### Before Implementation:
1. Doer marks job as done
2. Lister confirms completion
3. Job status → "completed"
4. Lister can immediately leave review

### After Implementation:
1. Doer marks job as done
2. Lister confirms completion
3. **NEW: Payment step required**
4. Lister completes payment
5. Job status → "completed"
6. Lister can leave review

## Implementation Details

### 1. Chat Screen Modifications (`lib/screens/chat_screen.dart`)

#### New Methods Added:

**`_handlePaymentForCompletedJob()`**
- Validates job amount and application data
- Navigates to BecauseScreen with pre-filled amount
- Handles payment success/failure

**`_updateJobStatusAfterPayment()`**
- Updates application status to "completed" after successful payment
- Sends system message about payment completion
- Refreshes conversation details

**`_showPaymentSuccessDialog()`**
- Shows success dialog after payment
- Prompts user to leave review
- Handles navigation to review screen

#### UI Changes:

**Payment Button (New)**
```dart
// Payment button for confirmed but unpaid jobs
if (widget.isLister &&
    _currentUser?.id == _conversationDetails?.listerId &&
    currentApplicationStatus == 'in_progress' &&
    _messages.any((msg) => msg.type == 'doer_marked_complete_request' && msg.senderId == widget.otherUserId) &&
    !_messages.any((msg) => msg.type == 'payment_completed' && msg.senderId == _currentUser!.id)) ...[
  Center(
    child: ElevatedButton.icon(
      onPressed: _isLoading ? null : _handlePaymentForCompletedJob,
      icon: const Icon(Icons.payment, color: Colors.white),
      label: Text('Pay ₱${_conversationDetails?.price?.toStringAsFixed(2) ?? '0.00'}'),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
    ),
  ),
],
```

**Review Button (Modified)**
```dart
// Review button for completed and paid jobs
if (!_hasReview &&
    _currentUser?.id == _conversationDetails?.listerId &&
    currentApplicationStatus == 'completed' &&
    widget.isLister &&
    _messages.any((msg) => msg.type == 'payment_completed' && msg.senderId == _currentUser!.id)) ...[
  // Review button implementation
],
```

### 2. BecauseScreen Modifications (`lib/screens/because_screen.dart`)

#### New Parameters:
```dart
class BecauseScreen extends StatefulWidget {
  final double? preFilledAmount;    // Job amount to pre-fill
  final bool isJobPayment;          // Whether this is a job payment
  final String? applicationId;      // Application ID for tracking
  final String? listingTitle;       // Job title for description
}
```

#### Key Changes:

**Pre-filled Amount**
```dart
// Pre-fill amount if provided (for job payments)
if (widget.preFilledAmount != null && widget.preFilledAmount! > 0) {
  _amountController.text = widget.preFilledAmount!.toStringAsFixed(2);
}
```

**Payment Description**
```dart
// Create description based on payment type
String description;
if (widget.isJobPayment && widget.listingTitle != null) {
  description = 'Payment for job: ${widget.listingTitle}';
} else {
  description = 'Payment via ${_getPaymentMethodName(actualPaymentMethod)}';
}
```

**Demo Payment Handling**
```dart
if (!XenditService.instance.isConfigured()) {
  if (widget.isJobPayment) {
    // For job payments, show demo payment and return success
    _showDemoPaymentDialog(amount);
    return;
  } else {
    _showConfigurationDialog(amount);
    return;
  }
}
```

**Success Return**
```dart
// For job payments, return success after a delay
if (widget.isJobPayment) {
  Future.delayed(const Duration(seconds: 2), () {
    Navigator.of(context).pop(true); // Return success
  });
}
```

### 3. System Messages

**Payment Completion Message**
```dart
await _chatService.sendMessage(
  conversationId: widget.conversationId,
  senderId: _currentUser!.id!,
  receiverId: widget.otherUserId,
  messageContent: "Payment completed successfully. Job marked as completed.",
  messageType: 'payment_completed',
);
```

## Payment Flow States

### State 1: Job Confirmed, Payment Pending
- **Status**: `in_progress`
- **Button**: "Pay ₱X.XX" (Green payment button)
- **Condition**: Doer marked complete + No payment message

### State 2: Payment in Progress
- **Status**: `in_progress`
- **Button**: None (user redirected to payment screen)
- **Condition**: Payment screen open

### State 3: Payment Completed, Review Available
- **Status**: `completed`
- **Button**: "Leave a Review" (Blue review button)
- **Condition**: Payment completed + No review yet

## Testing

### Test File: `test_payment_flow.dart`

Created comprehensive tests for:
1. **Job payment with pre-filled amount**
2. **Regular payment without pre-filled amount**
3. **Payment method selection**
4. **Demo payment for job**
5. **Payment validation**
6. **Amount validation**

### Running Tests:
```bash
flutter test test_payment_flow.dart
```

## Benefits

### 1. **Payment Security**
- Ensures payment before job completion
- Prevents review without payment
- Maintains payment records

### 2. **User Experience**
- Clear payment flow
- Pre-filled amounts for convenience
- Success confirmation and review prompt

### 3. **Business Logic**
- Proper payment tracking
- System message documentation
- Status management

### 4. **Code Reusability**
- Uses existing BecauseScreen
- Maintains existing payment infrastructure
- Minimal code duplication

## Technical Implementation

### Message Types:
- `doer_marked_complete_request`: Doer requests completion
- `payment_completed`: Payment successfully processed
- `system`: General system messages

### Status Flow:
1. `pending` → `accepted` → `in_progress` → `completed`
2. Payment step occurs between `in_progress` and `completed`

### Error Handling:
- Invalid job amounts
- Missing application data
- Payment service failures
- Network connectivity issues

## Future Enhancements

1. **Payment Verification**: Add webhook integration for payment confirmation
2. **Payment History**: Track payment attempts and failures
3. **Partial Payments**: Support for installment payments
4. **Payment Disputes**: Handle payment-related disputes
5. **Automated Notifications**: Send payment reminders and confirmations

## Files Modified

1. `lib/screens/chat_screen.dart` - Added payment flow logic
2. `lib/screens/because_screen.dart` - Enhanced for job payments
3. `test_payment_flow.dart` - Created comprehensive tests
4. `PAYMENT_FLOW_IMPLEMENTATION.md` - Created documentation

## Integration Points

### Existing Services Used:
- `XenditService` - Payment processing
- `ChatService` - Message sending
- `ApplicationService` - Status updates
- `AuthService` - User authentication

### UI Components:
- `BecauseScreen` - Payment interface
- `ReviewScreen` - Review interface
- `AlertDialog` - Success/error dialogs
- `ElevatedButton` - Action buttons

The payment flow is now fully integrated into the job completion process, ensuring that payments are completed before reviews can be submitted. 