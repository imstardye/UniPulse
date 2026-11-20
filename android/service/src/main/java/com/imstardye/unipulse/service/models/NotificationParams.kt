package com.imstardye.unipulse.service.models

data class NotificationParams(
    val title: String = "UniPulse",
    val stopText: String = "STOP",
    val onlyStatisticsProxy: Boolean = false,
    val showStopAction: Boolean = true,
)
