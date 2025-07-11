<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Category extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'type',
        'slug',
        'description',
        'image',
        'color',
        'icon',
        'is_active'
    ];

    protected $casts = [
        'is_active' => 'boolean'
    ];

    public function recipes()
    {
        return $this->hasMany(Recipe::class);
    }

    public function tips()
    {
        return $this->hasMany(Tip::class);
    }

    public function events()
    {
        return $this->hasMany(Event::class);
    }

    public function getImageUrlAttribute()
    {
        return $this->image ? asset('storage/' . $this->image) : null;
    }

    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    public function scopeByType($query, $type)
    {
        return $query->where('type', $type);
    }

    public function scopeForEvents($query)
    {
        return $query->where('type', 'event');
    }

    public function scopeForRecipes($query)
    {
        return $query->where('type', 'recipe');
    }

    public function scopeGeneral($query)
    {
        return $query->where('type', 'general');
    }
} 