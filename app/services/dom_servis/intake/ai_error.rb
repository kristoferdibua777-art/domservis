# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Raised when the AI service of the pasted text reading fails. The message
# is shown to the dispatcher or the admin as it is, so it says what to do.
class DomServis::Intake::AIError < StandardError; end
