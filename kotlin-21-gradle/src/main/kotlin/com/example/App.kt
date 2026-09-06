package com.example

import org.slf4j.LoggerFactory

object App {
    private val logger = LoggerFactory.getLogger(App::class.java)

    @JvmStatic
    fun main(args: Array<String>) {
        logger.info("SSDLC POC - Kotlin 2.0 (JVM 21) Service is running.")
    }
}
