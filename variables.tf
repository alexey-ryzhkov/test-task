variable "key_id" {
  type        = string
  description = "Access Key Id"
  #default     = ""
}

variable "key_secret" {
  type        = string
  description = "Secret Access Key"
  #default     = ""
}

variable "words" {
  type        = map(any)
  description = "DynamoDB items"
  default = {
    word1 = {
      word = "car"
    },
    word2 = {
      word = "truck"
    },
    word3 = {
      word = "banana"
    }
  }
}
