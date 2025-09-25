FROM ruby:3.2-slim

# Install system dependencies
RUN apt-get update && apt-get install -y build-essential

# Set working directory
WORKDIR /app

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install Ruby dependencies
RUN bundle install

# Copy application code
COPY . .

# Expose port
EXPOSE 4567

# Start the application
CMD ["./api.rb"]
