﻿using UnityEngine;
using System.Collections;

namespace Flux
{
    [FEvent("模型控制/冲刺", typeof(FCharacterTrack))]
    public class FRushEvent : FEvent
    {
        [SerializeField]
        [HideInInspector]
        private int _angle;
        [SerializeField]
        [HideInInspector]
        private float _length;
        private FTweenVector3 _tween;
        private Vector3 _startPosition;
 
        protected override void OnTrigger(float timeSinceTrigger)
        {
            _startPosition = Owner.localPosition;
            base.OnTrigger(timeSinceTrigger);

            Owner.Rotate(Vector3.up * _angle);
            Vector3 from = Owner.position;
            Vector3 to = Owner.position + Owner.forward * _length;
            _tween = new FTweenVector3(from, to);
        }

        protected override void OnStop()
        {
            base.OnStop();
            Owner.localPosition = _startPosition;
        }
        protected override void OnUpdateEvent(float timeSinceTrigger)
        {
            float t = timeSinceTrigger / LengthTime;

            Owner.position = _tween.GetValue(t);
        }
    }
}