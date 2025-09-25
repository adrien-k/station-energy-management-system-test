# frozen_string_literal: true

class ClientError < StandardError; end
class NotFoundError < ClientError; end
