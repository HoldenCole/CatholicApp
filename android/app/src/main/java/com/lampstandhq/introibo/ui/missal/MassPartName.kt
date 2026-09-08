package com.lampstandhq.introibo.ui.missal

import com.lampstandhq.introibo.data.content.ContentStore

/**
 * Vernacular names of the Mass parts (missal.part.<id>); the Latin halves
 * of the section labels are literals at the call sites.
 *
 * iOS mirror: MassPartName in Introibo/Screens/Missal/ProperView.swift
 */
object MassPartName {
    fun of(id: String, en: String): String = ContentStore.uiString("missal.part.$id", en)
    val introit: String get() = of("introit", "Introit")
    val collect: String get() = of("collect", "Collect")
    val epistle: String get() = of("epistle", "Epistle")
    val gradual: String get() = of("gradual", "Gradual")
    val alleluia: String get() = of("alleluia", "Alleluia")
    val tract: String get() = of("tract", "Tract")
    val sequence: String get() = of("sequence", "Sequence")
    val gospel: String get() = of("gospel", "Gospel")
    val offertory: String get() = of("offertory", "Offertory")
    val secret: String get() = of("secret", "Secret")
    val preface: String get() = of("preface", "Preface")
    val communion: String get() = of("communion", "Communion")
    val postcommunion: String get() = of("postcommunion", "Postcommunion")
}
