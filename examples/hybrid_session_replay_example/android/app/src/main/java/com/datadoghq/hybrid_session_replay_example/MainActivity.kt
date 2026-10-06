/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2026-Present Datadog, Inc.
 */

package com.datadoghq.hybrid_session_replay_example

import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.CompoundButton
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.Switch
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.datadoghq.flutter.sessionreplay.enableSessionReplay
import com.google.android.material.button.MaterialButton
import com.google.android.material.button.MaterialButtonToggleGroup
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterFragment

/**
 * Native controls screen, mirroring `FirstViewController.swift` in the iOS host: a slider, a
 * switch, a segmented-style toggle, an embedded Flutter panel, radio buttons and icon buttons, plus
 * a button that pushes a full screen Flutter view.
 */
class MainActivity : AppCompatActivity() {

    private lateinit var sliderValueLabel: TextView
    private lateinit var switchStateLabel: TextView
    private lateinit var segmentedValueLabel: TextView
    private lateinit var radioValueLabel: TextView
    private lateinit var iconStatusLabel: TextView

    private val radioOptions = listOf("Small", "Medium", "Large")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildUi())
    }

    private fun buildUi(): View {
        val stack = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20))
        }

        stack.addView(header("Welcome", "Try the native controls below"))
        stack.addView(sliderSection())
        stack.addView(switchSection())
        stack.addView(segmentedSection())
        stack.addView(embeddedFlutterSection())
        stack.addView(radioSection())
        stack.addView(iconButtonsSection())
        stack.addView(openFlutterButton())

        return ScrollView(this).apply {
            addView(stack)
            // Targeting API 35 draws the app edge to edge, so keep the content clear of the status
            // and navigation bars.
            ViewCompat.setOnApplyWindowInsetsListener(this) { view, insets ->
                val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
                view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
                insets
            }
        }
    }

    // region Sections

    private fun header(title: String, subtitle: String): View {
        val titleLabel = TextView(this).apply {
            text = title
            textSize = 24f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }
        val subtitleLabel = TextView(this).apply {
            text = subtitle
            textSize = 13f
            setTextColor(Color.GRAY)
        }
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(titleLabel)
            addView(subtitleLabel)
            setSectionMargins(this)
        }
    }

    private fun sliderSection(): View {
        sliderValueLabel = TextView(this).apply { text = "Value: 50" }
        val slider = SeekBar(this).apply {
            max = 100
            progress = 50
            setOnSeekBarChangeListener(
                object : SeekBar.OnSeekBarChangeListener {
                    override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                        sliderValueLabel.text = "Value: $progress"
                    }

                    override fun onStartTrackingTouch(seekBar: SeekBar?) = Unit
                    override fun onStopTrackingTouch(seekBar: SeekBar?) = Unit
                }
            )
        }
        return cardSection("Slider", slider, sliderValueLabel)
    }

    private fun switchSection(): View {
        switchStateLabel = TextView(this).apply { text = "State: OFF" }
        val toggle = Switch(this).apply {
            isChecked = false
            setOnCheckedChangeListener { _: CompoundButton, isChecked: Boolean ->
                switchStateLabel.text = "State: ${if (isChecked) "ON" else "OFF"}"
            }
        }
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(
                TextView(this@MainActivity).apply {
                    text = "Enable notifications"
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                }
            )
            addView(toggle)
        }
        return cardSection("Switch", row, switchStateLabel)
    }

    private fun segmentedSection(): View {
        segmentedValueLabel = TextView(this).apply { text = "Selected: One" }
        val options = listOf("One", "Two", "Three")
        val group = MaterialButtonToggleGroup(this).apply {
            isSingleSelection = true
            isSelectionRequired = true
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { gravity = Gravity.CENTER_HORIZONTAL }
        }
        options.forEachIndexed { index, label ->
            // Outlined buttons, so only the checked one is filled in.
            val button = MaterialButton(
                this,
                null,
                com.google.android.material.R.attr.materialButtonOutlinedStyle
            ).apply {
                text = label
                id = View.generateViewId()
            }
            group.addView(button)
            if (index == 0) group.check(button.id)
        }
        group.addOnButtonCheckedListener { _, checkedId, isChecked ->
            if (!isChecked) return@addOnButtonCheckedListener
            val index = group.indexOfChild(group.findViewById(checkedId))
            segmentedValueLabel.text = "Selected: ${options[index]}"
        }
        return cardSection("Segmented Control", group, segmentedValueLabel)
    }

    private fun embeddedFlutterSection(): View {
        val container = FrameLayout(this).apply {
            id = View.generateViewId()
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(220)
            )
        }

        val titleLabel = TextView(this).apply {
            text = "Embedded Flutter Panel"
            textSize = 17f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16))
            setBackgroundColor(Color.parseColor("#F2F2F7"))
            addView(titleLabel)
            addView(container)
        }
        setSectionMargins(card)

        val flutterFragment = FlutterFragment.withCachedEngine(HybridApplication.EMBEDDED_ENGINE_ID)
            .build<FlutterFragment>()
        // Opts the embedded Flutter view in to the native Session Replay, so its content is
        // composited into this screen's replay where the panel sits.
        flutterFragment.enableSessionReplay()

        supportFragmentManager.beginTransaction()
            .replace(container.id, flutterFragment)
            .commitNow()

        return card
    }

    private fun radioSection(): View {
        radioValueLabel = TextView(this).apply { text = "Selected: ${radioOptions[0]}" }
        val group = RadioGroup(this).apply { orientation = LinearLayout.VERTICAL }
        radioOptions.forEachIndexed { index, option ->
            val button = RadioButton(this).apply {
                text = option
                id = View.generateViewId()
                isChecked = index == 0
            }
            group.addView(button)
        }
        group.setOnCheckedChangeListener { radioGroup, checkedId ->
            val index = radioGroup.indexOfChild(radioGroup.findViewById(checkedId))
            radioValueLabel.text = "Selected: ${radioOptions[index]}"
        }
        return cardSection("Radio Buttons", group, radioValueLabel)
    }

    private fun iconButtonsSection(): View {
        iconStatusLabel = TextView(this).apply { text = "Tap an icon" }
        val icons = listOf("❤️" to "Heart", "⭐" to "Star", "🔔" to "Bell",
            "🔖" to "Bookmark", "✈️" to "Send")

        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        icons.forEach { (glyph, name) ->
            val button = Button(this).apply {
                text = glyph
                textSize = 22f
                contentDescription = name
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                setOnClickListener { iconStatusLabel.text = "Tapped: $name" }
            }
            row.addView(button)
        }
        return cardSection("Icon Buttons", row, iconStatusLabel)
    }

    private fun openFlutterButton(): View {
        return Button(this).apply {
            text = "Open Flutter View"
            setOnClickListener {
                startActivity(
                    FlutterActivity.CachedEngineIntentBuilder(
                        HybridFlutterActivity::class.java,
                        HybridApplication.MAIN_ENGINE_ID
                    ).build(this@MainActivity)
                )
            }
        }
    }

    // endregion

    // region Helpers

    private fun cardSection(title: String, control: View, valueLabel: TextView): View {
        val titleLabel = TextView(this).apply {
            text = title
            textSize = 17f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16))
            setBackgroundColor(Color.parseColor("#F2F2F7"))
            addView(titleLabel)
            addView(control)
            addView(valueLabel)
        }
        setSectionMargins(card)
        return card
    }

    private fun setSectionMargins(view: View) {
        val params = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        params.bottomMargin = dp(24)
        view.layoutParams = params
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun View.setPadding(all: Int) = setPadding(all, all, all, all)

    // endregion
}
