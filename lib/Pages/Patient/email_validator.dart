library email_validator;

class EmailValidator {
  /// Validates an email address based on common RFC 5322 standards.
  /// Returns `true` if the email is valid, `false` otherwise.
  static bool validate(String? email) {
    if (email == null || email.isEmpty) return false;

    // Trim the email to remove leading/trailing whitespace
    email = email.trim();

    // Basic length check (max 254 characters per RFC 5321)
    if (email.length > 254) return false;

    // Regular expression for email validation
    // Allows: alphanumeric, dots, hyphens, underscores, plus sign before domain
    // Disallows: consecutive dots, spaces, or invalid characters
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
    );

    // Check if the email matches the regex
    if (!emailRegex.hasMatch(email)) return false;

    // Split into local part and domain
    final parts = email.split('@');
    if (parts.length != 2) return false;

    final localPart = parts[0];
    final domain = parts[1];

    // Local part checks (max 64 characters per RFC 5321)
    if (localPart.length > 64) return false;
    if (localPart.contains('..') || localPart.startsWith('.') || localPart.endsWith('.')) return false;

    // Domain checks (max 253 characters for full domain)
    if (domain.length > 253) return false;
    if (domain.startsWith('-') || domain.endsWith('-')) return false;

    // Ensure domain has at least one dot and valid TLD
    final domainParts = domain.split('.');
    if (domainParts.length < 2) return false;
    if (domainParts.any((part) => part.isEmpty || part.length > 63)) return false;

    return true;
  }
}